package websocket

import (
	"encoding/json"
	"log/slog"
	"sync"

	"github.com/gin-gonic/gin"
	ws "github.com/gorilla/websocket"
)

var (
	chatRooms   = make(map[string][]*ws.Conn)
	chatRoomsMu sync.Mutex
)

func HandleChatWS(c *gin.Context) {
	chatID := c.Param("chatId")
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		slog.Error("chat WS upgrade error", "err", err)
		return
	}

	chatRoomsMu.Lock()
	chatRooms[chatID] = append(chatRooms[chatID], conn)
	chatRoomsMu.Unlock()

	defer func() {
		conn.Close()
		chatRoomsMu.Lock()
		conns := chatRooms[chatID]
		for i, c := range conns {
			if c == conn {
				chatRooms[chatID] = append(conns[:i], conns[i+1:]...)
				break
			}
		}
		if len(chatRooms[chatID]) == 0 {
			delete(chatRooms, chatID)
		}
		chatRoomsMu.Unlock()
	}()

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		// Broadcast to all connections in this chat room
		chatRoomsMu.Lock()
		for _, c := range chatRooms[chatID] {
			if c != conn {
				c.WriteMessage(ws.TextMessage, raw)
			}
		}
		chatRoomsMu.Unlock()
	}
}

// BroadcastToChat sends a message to all WebSocket connections in a chat room.
// Called from the HTTP SendMessage handler after saving to DB.
func BroadcastToChat(chatID string, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	chatRoomsMu.Lock()
	defer chatRoomsMu.Unlock()
	for _, c := range chatRooms[chatID] {
		c.WriteMessage(ws.TextMessage, data)
	}
}
