// mixed stress scenario
//
// Realistic-ish mixed workload: one cohort of users is actively battling
// over WebSocket while another cohort is browsing the home screen (REST).
// This exercises the contention we actually care about — the WS goroutines
// hold battleMu/queueMu and the battle-end goroutine writes to the users
// table at the same moment leaderboard / history queries are hitting it.
//
// Default split:
//   - 40% of users are "battlers"  — pair up, battle, repeat
//   - 60% of users are "browsers"  — poll REST endpoints continuously
//
// Useful for finding: db pool exhaustion, lock convoys in battle_ws.go,
// goroutine leaks from early disconnects.
package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"pixelmatch-server/stress/internal/fixtures"
	"pixelmatch-server/stress/internal/metrics"
	"pixelmatch-server/stress/internal/wsclient"
)

func main() {
	base := flag.String("base", "http://localhost:8080", "server base URL")
	totalUsers := flag.Int("users", 30, "total users to register")
	battlerFrac := flag.Float64("battler-fraction", 0.4, "fraction of users running WS battle loop")
	duration := flag.Duration("duration", 60*time.Second, "total scenario wall time")
	setupPar := flag.Int("setup-parallelism", 4, "registration parallelism (auth rate limited)")
	hitInterval := flag.Duration("hit-interval", 300*time.Millisecond, "WS tower_hit interval")
	restInterval := flag.Duration("rest-interval", 500*time.Millisecond, "delay between REST iterations per browser")
	flag.Parse()

	nBattlers := int(float64(*totalUsers) * *battlerFrac)
	if nBattlers%2 != 0 {
		nBattlers-- // even count so they pair cleanly
	}
	if nBattlers < 2 {
		nBattlers = 2
	}
	nBrowsers := *totalUsers - nBattlers

	log.Printf("mixed stress: base=%s users=%d (battlers=%d, browsers=%d) duration=%s",
		*base, *totalUsers, nBattlers, nBrowsers, *duration)

	users, err := fixtures.CreateUsers(*base, *totalUsers, *setupPar)
	if err != nil {
		log.Fatalf("user setup: %v", err)
	}

	battlers := users[:nBattlers]
	browsers := users[nBattlers:]

	// recorders
	rMe := metrics.NewRecorder("REST GET /me", 4096)
	rElig := metrics.NewRecorder("REST GET /users/eligible", 2048)
	rLB := metrics.NewRecorder("REST GET /leaderboard", 2048)
	rHist := metrics.NewRecorder("REST GET /battles/history", 2048)
	rMatch := metrics.NewRecorder("WS match", nBattlers)
	rRTT := metrics.NewRecorder("WS tower_hit rtt", nBattlers*100)
	rBattle := metrics.NewRecorder("WS battle duration", nBattlers)

	var (
		peakConns    atomic.Int64
		liveConns    atomic.Int64
		battlesDone  atomic.Int64
		battlesRound atomic.Int64
	)

	stopAt := time.Now().Add(*duration)
	start := time.Now()

	var wg sync.WaitGroup

	// ---- browsers ----
	for i, u := range browsers {
		wg.Add(1)
		go func(i int, u *fixtures.TestUser) {
			defer wg.Done()
			rng := rand.New(rand.NewSource(int64(i) ^ time.Now().UnixNano()))
			cli := u.AuthedClient(*base, 15*time.Second)
			ticker := time.NewTicker(*restInterval)
			defer ticker.Stop()
			for {
				if time.Now().After(stopAt) {
					return
				}
				<-ticker.C

				d, err := cli.GetMe()
				rMe.Record(d, err == nil)

				// randomize which heavier query runs this iteration
				switch rng.Intn(3) {
				case 0:
					d, err = cli.GetEligible()
					rElig.Record(d, err == nil)
				case 1:
					d, err = cli.GetLeaderboard()
					rLB.Record(d, err == nil)
				case 2:
					d, err = cli.GetBattleHistory()
					rHist.Record(d, err == nil)
				}
			}
		}(i, u)
	}

	// ---- battlers ----
	// They loop: connect -> match -> fight -> disconnect -> repeat until deadline.
	// Pair them off deterministically so pairs tend to start together.
	for i := 0; i < nBattlers; i++ {
		wg.Add(1)
		go func(i int, u *fixtures.TestUser) {
			defer wg.Done()
			rng := rand.New(rand.NewSource(int64(i)*31 ^ time.Now().UnixNano()))

			for {
				if time.Now().After(stopAt) {
					return
				}
				ok := runOneBattle(*base, u, *hitInterval, rng, rMatch, rRTT, rBattle, &liveConns, &peakConns, stopAt)
				if ok {
					battlesDone.Add(1)
				}
				battlesRound.Add(1)
				// tiny jitter so pairings don't lockstep
				time.Sleep(time.Duration(rng.Intn(150)) * time.Millisecond)
			}
		}(i, battlers[i])
	}

	wg.Wait()
	elapsed := time.Since(start)

	snaps := []metrics.Snapshot{
		rMe.Snapshot(elapsed), rElig.Snapshot(elapsed),
		rLB.Snapshot(elapsed), rHist.Snapshot(elapsed),
		rMatch.Snapshot(elapsed), rRTT.Snapshot(elapsed), rBattle.Snapshot(elapsed),
	}
	fmt.Printf("\nMixed stress report — wall time %s\n", elapsed.Round(time.Millisecond))
	fmt.Printf("battlers=%d browsers=%d   battles completed=%d (attempts=%d)   peak WS conns=%d\n",
		nBattlers, nBrowsers, battlesDone.Load(), battlesRound.Load(), peakConns.Load())
	metrics.PrintReport(os.Stdout, snaps)
}

// runOneBattle drives a single client through one battle. Returns true if
// it saw a natural battle_end (not cut off by deadline).
func runOneBattle(
	base string,
	u *fixtures.TestUser,
	hitInterval time.Duration,
	rng *rand.Rand,
	rMatch, rRTT, rBattle *metrics.Recorder,
	live, peak *atomic.Int64,
	deadline time.Time,
) bool {
	cli, err := wsclient.Dial(base, u.UID, u.CharClass)
	if err != nil {
		return false
	}
	defer cli.Close()

	now := live.Add(1)
	defer live.Add(-1)
	for {
		p := peak.Load()
		if now > p {
			if peak.CompareAndSwap(p, now) {
				break
			}
			continue
		}
		break
	}

	tJoin := time.Now()
	if err := cli.JoinQueue(); err != nil {
		return false
	}

	remain := time.Until(deadline)
	if remain <= 0 {
		return false
	}
	matchTimeout := remain
	if matchTimeout > 15*time.Second {
		matchTimeout = 15 * time.Second
	}

	if _, err := cli.WaitFor("battle_start", matchTimeout); err != nil {
		rMatch.Record(time.Since(tJoin), false)
		return false
	}
	rMatch.Record(time.Since(tJoin), true)

	ticker := time.NewTicker(hitInterval)
	defer ticker.Stop()
	pending := make(chan time.Time, 64)
	battleStart := time.Now()
	hardCutoff := time.After(30 * time.Second)

	// Send enough damage to win naturally: 1200hp / 50dmg = ~24 hits.
	for {
		select {
		case <-hardCutoff:
			rBattle.Record(time.Since(battleStart), false)
			return false
		case <-ticker.C:
			if rng.Intn(2) == 0 {
				_ = cli.DeployTroop(rng.Float64()*400, rng.Float64()*600)
			}
			select {
			case pending <- time.Now():
			default:
			}
			if err := cli.TowerHit(60); err != nil {
				rBattle.Record(time.Since(battleStart), false)
				return false
			}
		case m, ok := <-cli.In:
			if !ok {
				rBattle.Record(time.Since(battleStart), false)
				return false
			}
			switch m.Type {
			case "damage":
				select {
				case t := <-pending:
					rRTT.Record(time.Since(t), true)
				default:
				}
			case "battle_end":
				rBattle.Record(time.Since(battleStart), true)
				return true
			}
		}
	}
}
