package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"nhooyr.io/websocket"
	"nhooyr.io/websocket/wsjson"
	"strings"
	"sync"
	"time"
)

func main() {
	state := serverState{
		games: make(map[string]Game),
		mutex: sync.Mutex{},
	}

	mux := http.NewServeMux()
	mux.Handle("/", getOptionsHandler())
	mux.Handle("/ws", websocketHandler(&state))

	err := http.ListenAndServe(":3000", mux)
	if err != nil {
		panic(err)
	}
}

type ServerState interface {
	JoinOrNewGame(id string, playerName string) (Game, *Player, error)
}

func getOptionsHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodOptions {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		// TODO: not sure if correct
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Max-Age", "60")
		w.WriteHeader(http.StatusNoContent)
	}
}

func websocketHandler(state ServerState) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, err := websocket.Accept(w, r, &websocket.AcceptOptions{
			Subprotocols:         nil,
			InsecureSkipVerify:   false,
			OriginPatterns:       []websocket.OriginPattern{
				Scheme: "http", Host: "localhost", Port: "3000"}
			},
			CompressionMode:      0,
			CompressionThreshold: 0,
		})
		if err != nil {
			panic(err)
		}
		defer func(c *websocket.Conn, code websocket.StatusCode, reason string) {
			err := c.Close(code, reason)
			if err != nil {
				log.Println("error closing conn in deferred:", err)
			}
		}(c, websocket.StatusInternalError, "defer termination")

		ctx, cancel := context.WithTimeout(r.Context(), time.Second*10)
		defer cancel()

		var v interface{}
		err = wsjson.Read(ctx, c, &v)
		if err != nil {
			// ...
		}

		log.Printf("received: %v", v)

		err = c.Close(websocket.StatusNormalClosure, "normal termination")
		if err != nil {
			log.Println("error closing conn normally:", err)
			return
		}
	}
}

type serverState struct {
	games map[string]Game
	mutex sync.Mutex
}

func (s *serverState) JoinOrNewGame(id string, playerName string) (Game, *Player, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, nil, errors.New("id must not be empty")
	}

	playerName = strings.TrimSpace(playerName)
	if playerName == "" {
		playerName = "Unnamed Player"
	}

	game, err := (func(s *serverState) (Game, error) {
		s.mutex.Lock()
		defer s.mutex.Unlock()

		existing, ok := s.games[id]
		if ok {
			return existing, nil
		}

		game, err := NewGame(id)
		if err != nil {
			return nil, err
		}
		s.games[id] = game
		return game, nil
	})(s)
	if err != nil {
		return nil, nil, err
	}

	game.Lock()
	defer game.Unlock()

	player, err := game.AddPlayer(playerName)
	if err != nil {
		return nil, nil, err
	}

	return game, player, nil
}
