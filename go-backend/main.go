package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"go-backend/game"
	"log"
	"net/http"
	"nhooyr.io/websocket"
	"strings"
	"sync"
	"time"
)

func main() {
	state := serverState{
		games: make(map[string]game.Game),
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
	JoinOrNewGame(id string, playerName string) (game.Game, game.Player, error)
	DeleteGame(id string) error
}

func getOptionsHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodOptions {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		// TODO: not sure if correct
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:5173")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Max-Age", "60")
		w.WriteHeader(http.StatusNoContent)
	}
}

func websocketHandler(state ServerState) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		err := r.ParseForm()
		if err != nil {
			log.Println("error parsing form:", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		token := strings.TrimSpace(r.Form.Get("token"))
		if token == "" {
			token = randomToken()
		}
		playerName := strings.TrimSpace(r.Form.Get("name"))
		if playerName == "" {
			playerName = "Unnamed Player"
		}
		log.Println("token:", token, "name:", playerName)

		conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
			InsecureSkipVerify: true,
			OriginPatterns: []string{
				// TODO: should be configurable
				"http://localhost:5173",
			},
		})
		if err != nil {
			log.Println("error accepting websocket:", err)
			w.WriteHeader(http.StatusNotFound)
			return
		}

		var g game.Game
		var player game.Player

		defer func(c *websocket.Conn, g game.Game, playerId game.PlayerId) {
			err := c.Close(websocket.StatusNormalClosure, "defer termination")
			if err != nil && !strings.Contains(err.Error(), "already wrote close") {
				// totally fine if conn is already closed normally, otherwise log error
				log.Println("error closing conn in deferred:", err)
			}

			if g != nil {
				g.Lock()
				defer g.Unlock()

				if player.Id > 0 {
					err = g.RemovePlayer(player.Id)
					if err != nil {
						log.Println("error removing player:", err)
					}
				}

				if g.IsEmpty() {
					err = state.DeleteGame(g.Id())
					if err != nil {
						log.Println("error deleting game:", err)
					}
				}
			}
		}(conn, g, player.Id)

		g, player, err = state.JoinOrNewGame(token, playerName)
		if err != nil {
			log.Println("error joining game:", err)
			ctx, cancel := context.WithTimeout(r.Context(), time.Second*10)
			defer cancel()
			writeErr := conn.Write(ctx, websocket.MessageText, []byte("error joining game: "+err.Error()))
			if writeErr != nil {
				log.Println("error writing error to websocket:", writeErr)
			}
			return
		}

		// send joined game details to the client
		err = (func(token string, playerId game.PlayerId, state *game.State) error {
			msg := game.NewJoinedGameMsg(token, playerId, state)
			return sendJSON(r.Context(), conn, msg)
		})(token, player.Id, g.State())
		if err != nil {
			log.Println("error writing joined game msg:", err)
			return
		}

		// select loop to handle messages from client and state changes from game
		(func(game_ game.Game, playerId game.PlayerId, c *websocket.Conn) {
			incomingMsgs := make(chan []byte, 1)
			fatalSocketErr := make(chan error)

			go (func(c *websocket.Conn, incomingMsgs chan []byte, fatalSocketErr chan error) {
				for {
					_, msg, err := c.Read(context.Background())
					if err != nil {
						fatalSocketErr <- err
						return
					}
					incomingMsgs <- msg
				}
			})(c, incomingMsgs, fatalSocketErr)

			for {
				var gameState *game.State
				var msg []byte
				var decodedMsg game.FromBrowser
				var fatalErr error

				select {
				case <-r.Context().Done():
					// TODO: not sure if this context is meaningful
					log.Println("request context done")
					return
				case gameState = <-game_.StateChanges():
					log.Printf("state change: %+v", gameState)
					if err := sendJSON(r.Context(), c, game.NewGameStateMsg(gameState)); err != nil {
						log.Println("error sending state change:", err)
						return
					}
				case msg = <-incomingMsgs:
					log.Println("incoming msg:", string(msg))
					if err := json.NewDecoder(bytes.NewReader(msg)).Decode(&decodedMsg); err != nil {
						log.Println("error decoding msg:", err)
					}
					log.Printf("decoded msg: %+v", decodedMsg)
					if err := game_.HandleMsg(playerId, decodedMsg); err != nil {
						log.Println("error handling msg:", err)
						err := sendJSON(r.Context(), c, game.NewErrorMsg(err.Error()))
						if err != nil {
							log.Println("error sending error msg:", err)
							return
						}
					}
					game_.BroadcastState()

				case fatalErr = <-fatalSocketErr:
					log.Println("fatal socket error:", fatalErr)
					return
				}
			}
		})(g, player.Id, conn)
	}
}

func randomToken() string {
	return "TODO"
}

func sendJSON(ctx context.Context, conn *websocket.Conn, v interface{}) error {
	var buf bytes.Buffer
	err := json.NewEncoder(&buf).Encode(v)
	if err != nil {
		return err
	}
	return conn.Write(ctx, websocket.MessageText, buf.Bytes())
}

type serverState struct {
	games map[string]game.Game
	mutex sync.Mutex
}

func (s *serverState) JoinOrNewGame(id string, playerName string) (game.Game, game.Player, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, game.Player{}, errors.New("id must not be empty")
	}

	playerName = strings.TrimSpace(playerName)
	if playerName == "" {
		playerName = "Unnamed Player"
	}

	var player game.Player
	game_, err := (func(s *serverState) (game.Game, error) {
		s.mutex.Lock()
		defer s.mutex.Unlock()

		existing, ok := s.games[id]
		if ok {
			return existing, nil
		}

		game_, err := game.NewGame(id)
		if err != nil {
			return nil, err
		}
		s.games[id] = game_
		return game_, nil
	})(s)
	if err != nil {
		return nil, player, err
	}

	game_.Lock()
	defer game_.Unlock()

	player, err = game_.AddPlayer(playerName)
	if err != nil {
		return nil, player, err
	}

	return game_, player, nil
}

func (s *serverState) DeleteGame(id string) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	_, ok := s.games[id]
	if !ok {
		return errors.New("game not found")
	}

	delete(s.games, id)
	return nil
}
