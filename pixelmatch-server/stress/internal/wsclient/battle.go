// Package wsclient simulates a PixelMatch battle client over WebSocket.
// It speaks the message protocol defined in websocket/battle_ws.go:
//
//	join_queue      -> server replies "waiting" or broadcasts "battle_start"
//	deploy_troop    -> server re-broadcasts "troop_deployed"
//	tower_hit       -> server broadcasts "damage", then "battle_end" when HP<=0
//	leave_queue     -> drops player from queue
//
// The client does NOT validate game logic — its job is to generate realistic
// message volume so the server's WS hot path (and the in-memory battle map +
// timer goroutine) can be exercised.
package wsclient

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"sync"
	"time"

	ws "github.com/gorilla/websocket"
)

// Msg is a generic inbound message. We only need a few fields.
type Msg struct {
	Type     string          `json:"type"`
	BattleID string          `json:"battleId,omitempty"`
	WinnerID string          `json:"winnerUid,omitempty"`
	Players  json.RawMessage `json:"players,omitempty"`
	Raw      []byte          `json:"-"`
}

// Client holds a single WS connection and state for one simulated player.
type Client struct {
	Conn           *ws.Conn
	UID            string
	CharacterClass string

	// Populated when the server sends battle_start.
	BattleID string

	// Channel of inbound messages. Close-safe.
	In chan Msg

	closeOnce sync.Once
	closed    chan struct{}
}

// Dial connects to ws://HOST/ws/battle.
// baseURL is expected like "http://localhost:8080" — we swap scheme to ws.
func Dial(baseURL, uid, characterClass string) (*Client, error) {
	u, err := url.Parse(baseURL)
	if err != nil {
		return nil, err
	}
	switch u.Scheme {
	case "http":
		u.Scheme = "ws"
	case "https":
		u.Scheme = "wss"
	}
	u.Path = "/ws/battle"

	dialer := ws.Dialer{
		HandshakeTimeout: 10 * time.Second,
	}
	conn, _, err := dialer.Dial(u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("ws dial %s: %w", u.String(), err)
	}

	c := &Client{
		Conn:           conn,
		UID:            uid,
		CharacterClass: characterClass,
		In:             make(chan Msg, 64),
		closed:         make(chan struct{}),
	}
	go c.readLoop()
	return c, nil
}

func (c *Client) readLoop() {
	defer func() {
		c.closeOnce.Do(func() { close(c.closed) })
		close(c.In)
	}()
	for {
		_, data, err := c.Conn.ReadMessage()
		if err != nil {
			return
		}
		var m Msg
		if err := json.Unmarshal(data, &m); err != nil {
			continue
		}
		m.Raw = data
		if m.Type == "battle_start" && m.BattleID != "" {
			c.BattleID = m.BattleID
		}
		select {
		case c.In <- m:
		case <-c.closed:
			return
		}
	}
}

// JoinQueue sends the join_queue message. Server does NOT validate the token —
// auth is via payload UID, so we just put the registered UID here.
func (c *Client) JoinQueue() error {
	return c.send(map[string]interface{}{
		"type":           "join_queue",
		"uid":            c.UID,
		"characterClass": c.CharacterClass,
	})
}

// LeaveQueue sends leave_queue.
func (c *Client) LeaveQueue() error {
	return c.send(map[string]interface{}{"type": "leave_queue"})
}

// DeployTroop sends deploy_troop with a position.
func (c *Client) DeployTroop(x, y float64) error {
	if c.BattleID == "" {
		return errors.New("no battle in progress")
	}
	return c.send(map[string]interface{}{
		"type":     "deploy_troop",
		"battleId": c.BattleID,
		"uid":      c.UID,
		"x":        x,
		"y":        y,
	})
}

// TowerHit sends tower_hit. Server decrements the opposing tower's HP.
func (c *Client) TowerHit(damage int) error {
	if c.BattleID == "" {
		return errors.New("no battle in progress")
	}
	return c.send(map[string]interface{}{
		"type":     "tower_hit",
		"battleId": c.BattleID,
		"uid":      c.UID,
		"damage":   damage,
	})
}

// WaitFor drains the inbox until it sees a message of `msgType` or timeout.
func (c *Client) WaitFor(msgType string, timeout time.Duration) (Msg, error) {
	deadline := time.After(timeout)
	for {
		select {
		case m, ok := <-c.In:
			if !ok {
				return Msg{}, errors.New("connection closed")
			}
			if m.Type == msgType {
				return m, nil
			}
			// discard other types while waiting
		case <-deadline:
			return Msg{}, fmt.Errorf("timeout waiting for %s", msgType)
		}
	}
}

// Close shuts down the connection. Safe to call multiple times.
func (c *Client) Close() error {
	c.closeOnce.Do(func() { close(c.closed) })
	return c.Conn.Close()
}

// Closed returns a channel that's closed when the connection drops.
func (c *Client) Closed() <-chan struct{} { return c.closed }

func (c *Client) send(m map[string]interface{}) error {
	data, err := json.Marshal(m)
	if err != nil {
		return err
	}
	// gorilla/websocket requires serialized writes on a conn.
	// Each Client has its own conn, and we never share across goroutines
	// except via the single writer caller -> read loop split.
	return c.Conn.WriteMessage(ws.TextMessage, data)
}
