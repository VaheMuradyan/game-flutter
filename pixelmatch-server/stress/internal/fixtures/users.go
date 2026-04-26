// Package fixtures provides helpers to spin up pools of stress-test users.
// It registers fresh accounts with unique emails and completes onboarding
// so they pass server-side validation (display_name != '' filters in
// leaderboards and eligible-profile queries).
package fixtures

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"

	"pixelmatch-server/stress/internal/httpclient"
)

// TestUser represents a registered, onboarded stress-test account.
type TestUser struct {
	Email       string
	Password    string
	UID         string
	Token       string
	DisplayName string
	CharClass   string
}

// Classes is the set of valid character classes (mirrors auth.go validator).
var Classes = []string{"Warrior", "Mage", "Archer", "Rogue", "Healer"}

// CreateUsers registers N users in parallel (bounded by `parallelism`).
// It respects the auth rate limiter (10 req/min per IP by default) only in
// that it'll fail on 429s — scenarios should batch users or run this against
// a server started with a relaxed limit for load tests.
func CreateUsers(baseURL string, count, parallelism int) ([]*TestUser, error) {
	if parallelism <= 0 {
		parallelism = 8
	}
	users := make([]*TestUser, count)
	errs := make([]error, count)

	sem := make(chan struct{}, parallelism)
	var wg sync.WaitGroup

	runID := randHex(4)

	for i := 0; i < count; i++ {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int) {
			defer wg.Done()
			defer func() { <-sem }()

			email := fmt.Sprintf("stress_%s_%d_%d@pixelmatch.test", runID, time.Now().UnixNano(), i)
			password := "stresspassword123"
			display := fmt.Sprintf("s%s%d", runID, i)
			class := Classes[i%len(Classes)]

			cli := httpclient.New(baseURL, 15*time.Second)
			reg, _, err := cli.Register(email, password)
			if err != nil {
				errs[i] = fmt.Errorf("register: %w", err)
				return
			}
			if _, err := cli.Onboarding(display, class); err != nil {
				errs[i] = fmt.Errorf("onboarding: %w", err)
				return
			}
			users[i] = &TestUser{
				Email:       email,
				Password:    password,
				UID:         reg.User.UID,
				Token:       reg.Token,
				DisplayName: display,
				CharClass:   class,
			}
		}(i)
	}
	wg.Wait()

	for _, err := range errs {
		if err != nil {
			return users, err
		}
	}
	return users, nil
}

// AuthedClient returns an httpclient.Client pre-populated with the user's token.
func (u *TestUser) AuthedClient(baseURL string, timeout time.Duration) *httpclient.Client {
	c := httpclient.New(baseURL, timeout)
	c.Token = u.Token
	return c
}

func randHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
