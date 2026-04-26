// Package httpclient is a thin REST wrapper used by stress scenarios.
// It handles register / login / authenticated GETs and returns latency
// samples so callers can feed them into the metrics Recorder.
//
// Intentionally small — only the endpoints we need for stress. No retry,
// no connection pooling tweaks beyond Go's default transport (good enough
// for localhost stress on a dev box).
package httpclient

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Client wraps http.Client with a base URL and an optional bearer token.
type Client struct {
	BaseURL string
	Token   string
	HTTP    *http.Client
}

// New builds a Client. Timeout is applied to each request.
func New(baseURL string, timeout time.Duration) *Client {
	return &Client{
		BaseURL: baseURL,
		HTTP: &http.Client{
			Timeout: timeout,
			Transport: &http.Transport{
				MaxIdleConns:        512,
				MaxIdleConnsPerHost: 256,
				MaxConnsPerHost:     0, // unlimited; the OS will bound us
				IdleConnTimeout:     90 * time.Second,
				DisableCompression:  true,
			},
		},
	}
}

// Clone returns a shallow copy with the same transport. Used so each worker
// goroutine can carry its own token without racing on the shared Client.
func (c *Client) Clone() *Client {
	return &Client{BaseURL: c.BaseURL, Token: c.Token, HTTP: c.HTTP}
}

// RegisterResp / LoginResp mirror the server's AuthResponse shape, but
// only the fields we need.
type AuthResp struct {
	Token string `json:"token"`
	User  struct {
		UID         string `json:"uid"`
		Email       string `json:"email"`
		DisplayName string `json:"displayName"`
	} `json:"user"`
}

// Register hits POST /api/auth/register. Returns latency + error.
func (c *Client) Register(email, password string) (AuthResp, time.Duration, error) {
	body, _ := json.Marshal(map[string]string{"email": email, "password": password})
	var resp AuthResp
	d, err := c.do("POST", "/api/auth/register", body, &resp)
	if err == nil {
		c.Token = resp.Token
	}
	return resp, d, err
}

// Login hits POST /api/auth/login.
func (c *Client) Login(email, password string) (AuthResp, time.Duration, error) {
	body, _ := json.Marshal(map[string]string{"email": email, "password": password})
	var resp AuthResp
	d, err := c.do("POST", "/api/auth/login", body, &resp)
	if err == nil {
		c.Token = resp.Token
	}
	return resp, d, err
}

// Onboarding hits PUT /api/onboarding.
func (c *Client) Onboarding(displayName, characterClass string) (time.Duration, error) {
	body, _ := json.Marshal(map[string]string{
		"displayName":    displayName,
		"characterClass": characterClass,
	})
	d, err := c.do("PUT", "/api/onboarding", body, nil)
	return d, err
}

// GetMe hits GET /api/me.
func (c *Client) GetMe() (time.Duration, error) {
	return c.do("GET", "/api/me", nil, nil)
}

// GetEligible hits GET /api/users/eligible.
func (c *Client) GetEligible() (time.Duration, error) {
	return c.do("GET", "/api/users/eligible", nil, nil)
}

// GetLeaderboard hits GET /api/leaderboard.
func (c *Client) GetLeaderboard() (time.Duration, error) {
	return c.do("GET", "/api/leaderboard", nil, nil)
}

// GetLeagueLeaderboard hits GET /api/leaderboard/:league.
func (c *Client) GetLeagueLeaderboard(league string) (time.Duration, error) {
	return c.do("GET", "/api/leaderboard/"+league, nil, nil)
}

// GetBattleHistory hits GET /api/battles/history.
func (c *Client) GetBattleHistory() (time.Duration, error) {
	return c.do("GET", "/api/battles/history", nil, nil)
}

// GetSwipesToday hits GET /api/likes/today.
func (c *Client) GetSwipesToday() (time.Duration, error) {
	return c.do("GET", "/api/likes/today", nil, nil)
}

// GetMatches hits GET /api/matches.
func (c *Client) GetMatches() (time.Duration, error) {
	return c.do("GET", "/api/matches", nil, nil)
}

// RecordLike hits POST /api/likes.
func (c *Client) RecordLike(likedUID string) (time.Duration, error) {
	body, _ := json.Marshal(map[string]string{"likedUid": likedUID})
	return c.do("POST", "/api/likes", body, nil)
}

// Health hits GET /health (public, no auth).
func (c *Client) Health() (time.Duration, error) {
	return c.do("GET", "/health", nil, nil)
}

// do performs the request, decodes into `out` if non-nil, and returns latency.
// A non-2xx response is returned as an error so callers can mark it as failure.
func (c *Client) do(method, path string, body []byte, out interface{}) (time.Duration, error) {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequest(method, c.BaseURL+path, reader)
	if err != nil {
		return 0, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}

	start := time.Now()
	res, err := c.HTTP.Do(req)
	if err != nil {
		return time.Since(start), err
	}
	defer res.Body.Close()

	raw, err := io.ReadAll(res.Body)
	dur := time.Since(start)
	if err != nil {
		return dur, err
	}
	if res.StatusCode >= 400 {
		return dur, fmt.Errorf("%s %s: %d %s", method, path, res.StatusCode, truncate(raw, 200))
	}
	if out != nil && len(raw) > 0 {
		if err := json.Unmarshal(raw, out); err != nil {
			return dur, fmt.Errorf("decode %s: %w", path, err)
		}
	}
	return dur, nil
}

func truncate(b []byte, n int) string {
	if len(b) <= n {
		return string(b)
	}
	return string(b[:n]) + "..."
}
