// ws stress scenario
//
// Simulates N concurrent battle players. The server's matchmaker pairs
// clients in FIFO order as join_queue arrives (see websocket/battle_ws.go),
// so with even N players they'll be paired into N/2 concurrent battles.
//
// Each paired player:
//   1. dials /ws/battle
//   2. sends join_queue
//   3. waits for battle_start (measure matchmaking latency)
//   4. sends a steady stream of tower_hit (damage=50) + deploy_troop
//      messages until it sees battle_end OR the test's hard deadline fires
//   5. closes the connection
//
// Metrics reported:
//   - connect: time to open the WS
//   - match:   time from join_queue sent -> battle_start received
//   - rtt.tower_hit: round-trip from sending a tower_hit to receiving the
//                    resulting "damage" broadcast (proxy for WS latency
//                    under server lock contention)
//   - sustained concurrent battles (peak)
//   - battle completion counts + reasons (natural win vs. timeout)
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
	base := flag.String("base", "http://localhost:8080", "server base URL (http scheme; will be swapped to ws)")
	nPlayers := flag.Int("players", 20, "number of concurrent battle clients (even recommended; pairs become N/2 battles)")
	setupPar := flag.Int("setup-parallelism", 4, "registration parallelism (auth rate limited)")
	hitInterval := flag.Duration("hit-interval", 250*time.Millisecond, "delay between tower_hit messages per player")
	hitDamage := flag.Int("damage", 50, "damage per tower_hit (1200 hp means ~24 hits to win at 50)")
	maxBattle := flag.Duration("max-battle", 45*time.Second, "per-player hard deadline (battle_end or cutoff)")
	flag.Parse()

	log.Printf("ws stress: base=%s players=%d hit-interval=%s damage=%d max-battle=%s",
		*base, *nPlayers, *hitInterval, *hitDamage, *maxBattle)

	// --- setup users ---
	log.Printf("registering %d users...", *nPlayers)
	users, err := fixtures.CreateUsers(*base, *nPlayers, *setupPar)
	if err != nil {
		log.Fatalf("user setup failed: %v", err)
	}

	// --- metrics ---
	rConnect := metrics.NewRecorder("ws.connect", *nPlayers)
	rMatch := metrics.NewRecorder("ws.match (join->start)", *nPlayers)
	rRTT := metrics.NewRecorder("ws.tower_hit rtt", *nPlayers*50)
	rBattle := metrics.NewRecorder("ws.battle duration", *nPlayers)

	var (
		liveConns    atomic.Int64
		peakLive     atomic.Int64
		battlesEnded atomic.Int64
		battlesTimed atomic.Int64
		sendErrors   atomic.Int64
	)

	// --- start all clients roughly in parallel so they queue together ---
	var wg sync.WaitGroup
	start := time.Now()
	for i, u := range users {
		wg.Add(1)
		go func(i int, u *fixtures.TestUser) {
			defer wg.Done()
			rng := rand.New(rand.NewSource(int64(i) ^ time.Now().UnixNano()))

			tConn := time.Now()
			cli, err := wsclient.Dial(*base, u.UID, u.CharClass)
			rConnect.Record(time.Since(tConn), err == nil)
			if err != nil {
				log.Printf("player %d dial: %v", i, err)
				return
			}
			defer cli.Close()

			liveNow := liveConns.Add(1)
			for {
				peak := peakLive.Load()
				if liveNow > peak {
					if peakLive.CompareAndSwap(peak, liveNow) {
						break
					}
					continue
				}
				break
			}
			defer liveConns.Add(-1)

			// send join_queue + time to match
			tJoin := time.Now()
			if err := cli.JoinQueue(); err != nil {
				log.Printf("player %d join: %v", i, err)
				return
			}
			startMsg, err := cli.WaitFor("battle_start", *maxBattle)
			matchDur := time.Since(tJoin)
			rMatch.Record(matchDur, err == nil)
			if err != nil {
				// could be odd-N player stuck in queue — expected for 1 leftover
				log.Printf("player %d never matched: %v", i, err)
				return
			}
			_ = startMsg

			// battle loop — fire tower_hits on an interval, measure RTT to "damage"
			hitTicker := time.NewTicker(*hitInterval)
			defer hitTicker.Stop()
			deadline := time.After(*maxBattle)
			battleStart := time.Now()
			naturalEnd := false

			// pending send-times keyed by monotonic tick so we can compute RTT
			// crudely. The server rebroadcasts damage to both clients each hit,
			// so we just pair every sent tower_hit with the next damage frame.
			pending := make(chan time.Time, 64)

		loop:
			for {
				select {
				case <-deadline:
					break loop
				case <-hitTicker.C:
					// jitter deploy/hit to simulate real client traffic
					if rng.Intn(2) == 0 {
						if err := cli.DeployTroop(rng.Float64()*400, rng.Float64()*600); err != nil {
							sendErrors.Add(1)
						}
					}
					select {
					case pending <- time.Now():
					default:
					}
					if err := cli.TowerHit(*hitDamage); err != nil {
						sendErrors.Add(1)
					}
				case m, ok := <-cli.In:
					if !ok {
						break loop
					}
					switch m.Type {
					case "damage":
						select {
						case t := <-pending:
							rRTT.Record(time.Since(t), true)
						default:
						}
					case "battle_end":
						naturalEnd = true
						rBattle.Record(time.Since(battleStart), true)
						break loop
					}
				}
			}

			if naturalEnd {
				battlesEnded.Add(1)
			} else {
				battlesTimed.Add(1)
				rBattle.Record(time.Since(battleStart), false)
			}
		}(i, u)
	}

	wg.Wait()
	elapsed := time.Since(start)

	// --- report ---
	snaps := []metrics.Snapshot{
		rConnect.Snapshot(elapsed),
		rMatch.Snapshot(elapsed),
		rRTT.Snapshot(elapsed),
		rBattle.Snapshot(elapsed),
	}
	fmt.Printf("\nWS battle stress report — wall time %s, %d players\n", elapsed.Round(time.Millisecond), *nPlayers)
	fmt.Printf("peak concurrent WS connections: %d\n", peakLive.Load())
	fmt.Printf("battles with natural end:       %d\n", battlesEnded.Load())
	fmt.Printf("battles cut off at deadline:    %d\n", battlesTimed.Load())
	fmt.Printf("send errors:                    %d\n", sendErrors.Load())
	metrics.PrintReport(os.Stdout, snaps)
}
