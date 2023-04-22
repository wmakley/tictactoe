package server

import (
	"errors"
	"go-backend/game"
	"strings"
	"sync"
)

type State interface {
	sync.Locker
	JoinOrNewGame(id string, playerName string) (game.Game, game.Player, error)
	DeleteGame(id string) error
	Disconnects() chan Disconnect
}

type Disconnect struct {
	GameId   string
	PlayerId game.PlayerId
}

func NewState() State {
	return &serverState{
		games:       make(map[string]game.Game),
		mutex:       sync.Mutex{},
		disconnects: make(chan Disconnect, 100),
	}
}

type serverState struct {
	games       map[string]game.Game
	mutex       sync.Mutex
	disconnects chan Disconnect
}

func (s *serverState) Lock() {
	s.mutex.Lock()
}

func (s *serverState) Unlock() {
	s.mutex.Unlock()
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
	game_.BroadcastState()

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

func (s *serverState) Disconnects() chan Disconnect {
	return s.disconnects
}
