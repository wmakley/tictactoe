package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"go-backend/game"
	"go-backend/server"
	"log"
	"math/rand"
	"net/http"
	"nhooyr.io/websocket"
	"os"
	"strings"
	"time"
)

func main() {
	frontendUrl := os.Getenv("FRONTEND_URL")
	if frontendUrl == "" {
		frontendUrl = "http://localhost:5173"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	state := server.NewState()
	state.StartCleanup()

	mux := http.NewServeMux()
	mux.Handle("/", rootHandler(frontendUrl))
	mux.Handle("/health", healthCheckHandler())
	mux.Handle("/robots.txt", robotsTxtHandler())
	mux.Handle("/ws", websocketHandler(state))

	addr := fmt.Sprintf("0.0.0.0:%s", port)
	log.Println("listening on", addr)

	err := http.ListenAndServe(addr, mux)
	if err != nil {
		log.Fatal(err)
	}
}

func rootHandler(frontendUrl string) http.HandlerFunc {
	index := redirectToFrontendHandler(frontendUrl)
	options := getOptionsHandler(frontendUrl)

	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			index(w, r)
			return
		}

		if r.Method == http.MethodOptions {
			options(w, r)
			return
		}

		w.WriteHeader(http.StatusNotFound)
	}
}

func redirectToFrontendHandler(frontendUrl string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, frontendUrl, http.StatusFound)
	}
}

func getOptionsHandler(frontendUrl string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodOptions {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		w.Header().Set("Access-Control-Allow-Origin", frontendUrl)
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Max-Age", "3600")
		w.WriteHeader(http.StatusNoContent)
	}
}

func healthCheckHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}
}

func robotsTxtHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, err := w.Write([]byte("User-agent: *\nDisallow: /\n"))
		if err != nil {
			log.Println("error writing robots.txt:", err)
		}
	}
}

type connectionState struct {
	game     game.Game
	playerId game.PlayerId
}

func websocketHandler(state server.State) http.HandlerFunc {
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

		ctx := context.Background()
		incomingMsgs := make(chan []byte, 1)
		fatalSocketErr := make(chan error, 1)

		connState := connectionState{
			game:     nil,
			playerId: 0,
		}

		defer disconnect(conn, state, &connState)

		g, player, err := state.JoinOrNewGame(token, playerName)
		if err != nil {
			log.Println("error joining game:", err)
			writeErr := sendJSONWithTimeout(ctx, conn, game.NewErrorMsg("error joining game: "+err.Error()), 10*time.Second)
			if writeErr != nil {
				log.Println("error writing error to websocket:", writeErr)
			}
			return
		}
		connState.game = g
		connState.playerId = player.Id

		// send joined game details to the client
		msg := game.NewJoinedGameMsg(token, connState.playerId, g.State())
		err = sendJSONWithTimeout(ctx, conn, msg, 10*time.Second)
		if err != nil {
			log.Println(g.Id(), ": error sending joined game JSON:", err)
			return
		}

		go readFromWebsocket(conn, incomingMsgs, fatalSocketErr)

		for {
			var decodedMsg game.FromBrowser

			select {
			case newGameState := <-g.StateChanges():
				log.Printf("%s: game state changed, informing player id %d: %s", g.Id(), player.Id, newGameState.String())
				if err := sendJSONWithTimeout(r.Context(), conn, game.NewGameStateMsg(newGameState), 10*time.Second); err != nil {
					log.Println(g.Id(), ": fatal error sending game state JSON:", err)
					return
				}
			case msg := <-incomingMsgs:
				log.Println("incoming socket msg:", string(msg))
				decodeErr := json.NewDecoder(bytes.NewReader(msg)).Decode(&decodedMsg)
				if decodeErr != nil {
					log.Println(g.Id(), "fatal error decoding msg:", decodeErr)
					return
				} else {
					log.Printf("decoded msg: %+v", decodedMsg)
					g.Lock()
					err := g.HandleMsg(connState.playerId, decodedMsg)
					g.BroadcastState()
					g.Unlock()
					if err != nil {
						log.Println("error handling msg:", err)
						err := sendJSON(r.Context(), conn, game.NewErrorMsg(err.Error()))
						if err != nil {
							log.Println("error writing error to websocket:", err)
							return
						}
					}
				}

			case fatalErr := <-fatalSocketErr:
				log.Println("fatal socket error:", fatalErr)
				return
			}
		}
	}
}

func readFromWebsocket(c *websocket.Conn, incomingMsgs chan []byte, fatalSocketErr chan error) {
	for {
		_, msg, err := c.Read(context.Background())
		if err != nil {
			fatalSocketErr <- err
			return
		}
		incomingMsgs <- msg
	}
}

func disconnect(c *websocket.Conn, serverState server.State, connState *connectionState) {
	log.Println("closing websocket conn for playerId:", connState.playerId)

	err := c.Close(websocket.StatusNormalClosure, "defer termination")
	if err != nil && !strings.Contains(err.Error(), "already wrote close") {
		// totally fine if conn is already closed normally, otherwise log error
		log.Println("error closing conn in deferred:", err)
	}

	if connState.game != nil {
		log.Println("removing player from game id:", connState.game.Id())
		connState.game.Lock()
		defer connState.game.Unlock()

		if connState.playerId > 0 {
			log.Println("removing player:", connState.playerId)
			err = connState.game.RemovePlayer(connState.playerId)
			if err != nil {
				log.Println("error removing player:", err)
			}
		}

		if connState.game.IsEmpty() {
			serverState.EmptyGames() <- connState.game.Id()
		}
	}
}

func randomToken() string {
	return randStringRunes(5)
}

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func randStringRunes(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func sendJSON(ctx context.Context, conn *websocket.Conn, v interface{}) error {
	var buf bytes.Buffer
	err := json.NewEncoder(&buf).Encode(v)
	if err != nil {
		return err
	}
	return conn.Write(ctx, websocket.MessageText, buf.Bytes())
}

func sendJSONWithTimeout(ctx context.Context, conn *websocket.Conn, v interface{}, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	return sendJSON(ctx, conn, v)
}
