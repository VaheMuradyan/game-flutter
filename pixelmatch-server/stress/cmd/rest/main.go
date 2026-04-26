// rest stress scenario
//
// Spins up N concurrent workers, each authenticated as its own user,
// and hammers read-heavy + write-light REST endpoints that real clients
// exercise on startup / every home screen refresh.
//
// Endpoints covered per worker iteration (weighted):
//   - GET /api/me                   (2x  — hit on almost every screen)
//   - GET /api/users/eligible       (1x  — swipe deck fetch, heavy query)
//   - GET /api/leaderboard          (1x  — ORDER BY xp DESC LIMIT 50)
//   - GET /api/leaderboard/:league  (1x  — indexed filter)
//   - GET /api/likes/today          (1x  — COUNT(*) per call, per-user)
//   - GET /api/battles/history      (1x  — ORDER BY created_at DESC LIMIT 30)
//   - GET /api/matches              (1x  — JOIN users on match)
//
// Flags let you tune: -base, -users, -duration, -concurrency.
package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"sync"
	"time"

	"pixelmatch-server/stress/internal/fixtures"
	"pixelmatch-server/stress/internal/httpclient"
	"pixelmatch-server/stress/internal/metrics"
)

func main() {
	base := flag.String("base", "http://localhost:8080", "server base URL")
	nUsers := flag.Int("users", 20, "number of distinct authenticated users to simulate")
	concurrency := flag.Int("concurrency", 50, "number of concurrent workers")
	duration := flag.Duration("duration", 30*time.Second, "test duration")
	setupPar := flag.Int("setup-parallelism", 4, "parallelism for user registration (keep low; auth is rate limited)")
	flag.Parse()

	log.Printf("rest stress: base=%s users=%d concurrency=%d duration=%s",
		*base, *nUsers, *concurrency, *duration)

	// --- setup: create users ---
	log.Printf("registering %d users...", *nUsers)
	users, err := fixtures.CreateUsers(*base, *nUsers, *setupPar)
	if err != nil {
		log.Fatalf("user setup failed (hit auth rate limit? try fewer users or relax the limit): %v", err)
	}
	log.Printf("registered %d users", len(users))

	// --- metrics ---
	recs := map[string]*metrics.Recorder{
		"GET /api/me":                metrics.NewRecorder("GET /api/me", 4096),
		"GET /users/eligible":        metrics.NewRecorder("GET /users/eligible", 2048),
		"GET /leaderboard":           metrics.NewRecorder("GET /leaderboard", 2048),
		"GET /leaderboard/:league":   metrics.NewRecorder("GET /leaderboard/:league", 2048),
		"GET /likes/today":           metrics.NewRecorder("GET /likes/today", 2048),
		"GET /battles/history":       metrics.NewRecorder("GET /battles/history", 2048),
		"GET /matches":               metrics.NewRecorder("GET /matches", 2048),
	}

	// --- workers ---
	var wg sync.WaitGroup
	stop := time.After(*duration)
	start := time.Now()

	for w := 0; w < *concurrency; w++ {
		wg.Add(1)
		go func(w int) {
			defer wg.Done()
			rng := rand.New(rand.NewSource(int64(w) ^ time.Now().UnixNano()))
			// each worker uses a random user per iteration to spread auth load
			for {
				select {
				case <-stop:
					return
				default:
				}
				u := users[rng.Intn(len(users))]
				cli := u.AuthedClient(*base, 15*time.Second)
				runIteration(cli, rng, recs)
			}
		}(w)
	}

	wg.Wait()
	elapsed := time.Since(start)

	// --- report ---
	snaps := []metrics.Snapshot{}
	order := []string{
		"GET /api/me", "GET /users/eligible", "GET /leaderboard",
		"GET /leaderboard/:league", "GET /likes/today",
		"GET /battles/history", "GET /matches",
	}
	for _, k := range order {
		snaps = append(snaps, recs[k].Snapshot(elapsed))
	}
	fmt.Printf("\nREST stress report — wall time %s, %d users, %d workers\n",
		elapsed.Round(time.Millisecond), *nUsers, *concurrency)
	metrics.PrintReport(os.Stdout, snaps)
}

func runIteration(cli *httpclient.Client, rng *rand.Rand, recs map[string]*metrics.Recorder) {
	// GET /api/me twice — models real clients that hit it often
	for i := 0; i < 2; i++ {
		d, err := cli.GetMe()
		recs["GET /api/me"].Record(d, err == nil)
	}

	d, err := cli.GetEligible()
	recs["GET /users/eligible"].Record(d, err == nil)

	d, err = cli.GetLeaderboard()
	recs["GET /leaderboard"].Record(d, err == nil)

	leagues := []string{"Bronze", "Silver", "Gold", "Diamond", "Legend"}
	d, err = cli.GetLeagueLeaderboard(leagues[rng.Intn(len(leagues))])
	recs["GET /leaderboard/:league"].Record(d, err == nil)

	d, err = cli.GetSwipesToday()
	recs["GET /likes/today"].Record(d, err == nil)

	d, err = cli.GetBattleHistory()
	recs["GET /battles/history"].Record(d, err == nil)

	d, err = cli.GetMatches()
	recs["GET /matches"].Record(d, err == nil)
}
