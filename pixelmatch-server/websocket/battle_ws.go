package websocket

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	ws "github.com/gorilla/websocket"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
)

var upgrader = ws.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Player struct {
	Conn           *ws.Conn
	UID            string
	CharacterClass string
}

type BattleRoom struct {
	ID          string
	Players     [2]*Player
	TowerHealth [2]int
	StartTime   time.Time
	Duration    int
	Ended       bool
	mu          sync.Mutex
}

var (
	queue    []*Player
	queueMu  sync.Mutex
	battles  = make(map[string]*BattleRoom)
	battleMu sync.Mutex
)

func init() {
	// Timer loop to check battle timeouts
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		for range ticker.C {
			battleMu.Lock()
			for _, room := range battles {
				room.checkTimer()
			}
			battleMu.Unlock()
		}
	}()
}

func (r *BattleRoom) broadcast(msg map[string]interface{}) {
	data, _ := json.Marshal(msg)
	for _, p := range r.Players {
		if p != nil && p.Conn != nil {
			p.Conn.WriteMessage(ws.TextMessage, data)
		}
	}
}

func (r *BattleRoom) playerIndex(uid string) int {
	for i, p := range r.Players {
		if p != nil && p.UID == uid {
			return i
		}
	}
	return -1
}

func (r *BattleRoom) applyDamage(attackerUID string, damage int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	i := r.playerIndex(attackerUID)
	if i < 0 {
		return
	}
	targetIdx := 1 - i
	r.TowerHealth[targetIdx] -= damage
	if r.TowerHealth[targetIdx] < 0 {
		r.TowerHealth[targetIdx] = 0
	}

	r.broadcast(map[string]interface{}{
		"type":            "damage",
		"attackerUid":     attackerUID,
		"targetIdx":       targetIdx,
		"damage":          damage,
		"healthRemaining": r.TowerHealth[targetIdx],
	})

	if r.TowerHealth[targetIdx] <= 0 {
		r.endBattle(attackerUID)
	}
}

func (r *BattleRoom) endBattle(winnerUID string) {
	if r.Ended {
		return
	}
	r.Ended = true

	r.broadcast(map[string]interface{}{
		"type":        "battle_end",
		"winnerUid":   winnerUID,
		"towerHealth": r.TowerHealth,
	})

	// Save to database
	go saveBattleResult(r, winnerUID)
}

func (r *BattleRoom) checkTimer() {
	r.mu.Lock()
	defer r.mu.Unlock()

	elapsed := time.Since(r.StartTime).Seconds()
	if elapsed >= float64(r.Duration) && !r.Ended {
		winnerUID := r.Players[0].UID
		if r.TowerHealth[1] > r.TowerHealth[0] {
			winnerUID = r.Players[1].UID
		}
		r.endBattle(winnerUID)
	}
}

func saveBattleResult(room *BattleRoom, winnerUID string) {
	_, err := database.DB.Exec(`
		INSERT INTO battles (player1_uid, player2_uid, winner_uid, player1_health, player2_health, duration, xp_awarded)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, room.Players[0].UID, room.Players[1].UID, winnerUID,
		room.TowerHealth[0], room.TowerHealth[1], room.Duration, config.XPPerWin)
	if err != nil {
		slog.Error("failed to save battle", "err", err)
	}

	awardXP(room.Players[0].UID, room.Players[0].UID == winnerUID)
	awardXP(room.Players[1].UID, room.Players[1].UID == winnerUID)
}

func awardXP(uid string, won bool) {
	delta := config.XPPerLoss
	winIncr := 0
	lossIncr := 1
	if won {
		delta = config.XPPerWin
		winIncr = 1
		lossIncr = 0
	}

	var currentXP int
	if err := database.DB.QueryRow("SELECT xp FROM users WHERE uid = $1", uid).Scan(&currentXP); err != nil {
		slog.Error("failed to get user XP", "uid", uid, "err", err)
		return
	}

	newXP := currentXP + delta
	if newXP < config.MinXP {
		newXP = config.MinXP
	}

	newLevel := (newXP / 100) + 1
	newLeague := config.LeagueForLevel(newLevel)

	if _, err := database.DB.Exec(`
		UPDATE users SET xp = $1, level = $2, league = $3,
		       wins = wins + $4, losses = losses + $5
		WHERE uid = $6
	`, newXP, newLevel, newLeague, winIncr, lossIncr, uid); err != nil {
		slog.Error("failed to update user XP", "uid", uid, "err", err)
	}
}

// HandleBattleWS is the Gin handler for WebSocket connections.
func HandleBattleWS(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		slog.Error("WS upgrade error", "err", err)
		return
	}

	var currentPlayer *Player
	var currentRoomID string

	defer func() {
		conn.Close()
		// Remove from queue
		queueMu.Lock()
		for i, p := range queue {
			if p.Conn == conn {
				queue = append(queue[:i], queue[i+1:]...)
				break
			}
		}
		queueMu.Unlock()

		// End battle if in progress
		if currentRoomID != "" {
			battleMu.Lock()
			room, ok := battles[currentRoomID]
			battleMu.Unlock()
			if ok && !room.Ended && currentPlayer != nil {
				// Award win to the other player
				for _, p := range room.Players {
					if p != nil && p.UID != currentPlayer.UID {
						room.endBattle(p.UID)
						break
					}
				}
			}
		}
	}()

	for {
		_, rawMsg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(rawMsg, &msg); err != nil {
			continue
		}

		msgType, _ := msg["type"].(string)

		switch msgType {
		case "join_queue":
			uid, _ := msg["uid"].(string)
			charClass, _ := msg["characterClass"].(string)
			currentPlayer = &Player{Conn: conn, UID: uid, CharacterClass: charClass}

			queueMu.Lock()
			queue = append(queue, currentPlayer)

			if len(queue) >= 2 {
				p1 := queue[0]
				p2 := queue[1]
				queue = queue[2:]
				queueMu.Unlock()

				room := &BattleRoom{
					ID:          uuid.New().String(),
					Players:     [2]*Player{p1, p2},
					TowerHealth: [2]int{config.StartingTowerHealth, config.StartingTowerHealth},
					StartTime:   time.Now(),
					Duration:    config.BattleDurationSeconds,
				}

				battleMu.Lock()
				battles[room.ID] = room
				battleMu.Unlock()

				if p1.UID == currentPlayer.UID || p2.UID == currentPlayer.UID {
					currentRoomID = room.ID
				}

				room.broadcast(map[string]interface{}{
					"type":     "battle_start",
					"battleId": room.ID,
					"players": []map[string]string{
						{"uid": p1.UID, "characterClass": p1.CharacterClass},
						{"uid": p2.UID, "characterClass": p2.CharacterClass},
					},
				})
			} else {
				queueMu.Unlock()
				data, _ := json.Marshal(map[string]string{"type": "waiting"})
				conn.WriteMessage(ws.TextMessage, data)
			}

		case "deploy_troop":
			battleID, _ := msg["battleId"].(string)
			battleMu.Lock()
			room, ok := battles[battleID]
			battleMu.Unlock()
			if !ok {
				continue
			}
			room.broadcast(map[string]interface{}{
				"type": "troop_deployed",
				"uid":  msg["uid"],
				"x":    msg["x"],
				"y":    msg["y"],
			})

		case "tower_hit":
			battleID, _ := msg["battleId"].(string)
			uid, _ := msg["uid"].(string)
			damage := int(msg["damage"].(float64))
			battleMu.Lock()
			room, ok := battles[battleID]
			battleMu.Unlock()
			if !ok {
				continue
			}
			room.applyDamage(uid, damage)

		case "leave_queue":
			queueMu.Lock()
			for i, p := range queue {
				if p.Conn == conn {
					queue = append(queue[:i], queue[i+1:]...)
					break
				}
			}
			queueMu.Unlock()
		}
	}
}
