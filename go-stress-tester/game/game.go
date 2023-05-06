// Package game contains abbreviated copies of game data structures
// from backend implementation.
package game

import (
	"encoding/json"
	"errors"
	"fmt"
)

func NewState() *State {
	return &State{
		Turn:    TeamX,
		Winner:  EndState{},
		Players: []Player{},
		Board:   []Team{TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone, TeamNone},
		Chat:    []ChatMessage{},
	}
}

type State struct {
	Turn    Team          `json:"turn"`
	Winner  EndState      `json:"winner"`
	Players []Player      `json:"players"`
	Board   []Team        `json:"board"`
	Chat    []ChatMessage `json:"chat"`
}

type Team byte

const TeamNone Team = ' '
const TeamX Team = 'X'
const TeamO Team = 'O'

func (t *Team) MarshalJSON() ([]byte, error) {
	return json.Marshal(string(*t))
}

func (t *Team) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if len(s) != 1 {
		return errors.New("invalid team")
	}
	switch s[0] {
	case 'X':
		*t = TeamX
	case 'O':
		*t = TeamO
	case ' ':
		*t = TeamNone
	default:
		return errors.New("invalid team")
	}
	return nil
}

func (s State) String() string {
	return fmt.Sprintf("State{Turn: %s, Winner: %s, Players: %s, Board: %s, Chat: %+v}",
		string(s.Turn), s.Winner.String(), s.Players, s.Board, s.Chat)
}

func (s State) Clone() *State {
	return &State{
		Turn:    s.Turn,
		Winner:  s.Winner.Clone(),
		Players: s.clonePlayers(),
		Board:   s.cloneBoard(),
		Chat:    s.cloneChat(),
	}
}

func (s State) clonePlayers() []Player {
	players := make([]Player, len(s.Players))
	for i, player := range s.Players {
		players[i] = player.Clone()
	}
	return players
}

func (s State) cloneBoard() []Team {
	board := make([]Team, len(s.Board))
	copy(board, s.Board)
	return board
}

func (s State) cloneChat() []ChatMessage {
	chat := make([]ChatMessage, len(s.Chat))
	for i, message := range s.Chat {
		chat[i] = message.Clone()
	}
	return chat
}

type EndState struct {
	Done   bool
	Winner Team
	Draw   bool
}

func (e EndState) Clone() EndState {
	return EndState{
		Done:   e.Done,
		Winner: e.Winner,
		Draw:   e.Draw,
	}
}

func (e EndState) String() string {
	return fmt.Sprintf("EndState{Done: %t, Winner: %s, Draw: %t}", e.Done, string(e.Winner), e.Draw)
}

func (e EndState) MarshalJSON() ([]byte, error) {
	if !e.Done {
		return []byte(`null`), nil
	}
	if e.Draw {
		return []byte(`"Draw"`), nil
	}
	return []byte(`{"Win":"` + string(e.Winner) + `"}`), nil
}

type Player struct {
	Id   PlayerId `json:"id"`
	Team Team     `json:"team"`
	Name string   `json:"name"`
	Wins int32    `json:"wins"`
}

type PlayerId int32

func (p Player) String() string {
	return fmt.Sprintf("%s (%s)", p.Name, string(p.Team))
}

func (p Player) Clone() Player {
	return Player{
		Id:   p.Id,
		Team: p.Team,
		Name: p.Name,
		Wins: p.Wins,
	}
}

type ChatMessage struct {
	Id     int               `json:"id"`
	Source ChatMessageSource `json:"source"`
	Text   string            `json:"text"`
}

func (c ChatMessage) Clone() ChatMessage {
	return ChatMessage{
		Id:     c.Id,
		Source: c.Source,
		Text:   c.Text,
	}
}

type ChatMessageSource struct {
	SourceType int
	PlayerId   PlayerId
}

const SourceTypeSystem = 0
const SourceTypePlayer = 1

func PlayerSource(playerId PlayerId) ChatMessageSource {
	return ChatMessageSource{
		SourceType: SourceTypePlayer,
		PlayerId:   playerId,
	}
}

func SystemSource() ChatMessageSource {
	return ChatMessageSource{
		SourceType: SourceTypeSystem,
	}
}

func (c ChatMessageSource) MarshalJSON() ([]byte, error) {
	if c.SourceType == SourceTypeSystem {
		return []byte(`"System"`), nil
	}
	return []byte(fmt.Sprintf(`{"Player":%d}`, c.PlayerId)), nil
}

type FromBrowser struct {
	MsgType IncomingMsgType
	Text    string
	Space   int
}

type IncomingMsgType int

const (
	MsgTypeMove = iota
	MsgTypeChat
	MsgTypeChangeName
	MsgTypeRematch
)

var (
	ErrInvalidMessage = errors.New("invalid message")
)

func (m *FromBrowser) UnmarshalJSON(data []byte) error {
	//log.Println("data:", string(data))

	var stringMsg string
	if err := json.Unmarshal(data, &stringMsg); err == nil {
		if stringMsg == "Rematch" {
			m.MsgType = MsgTypeRematch
			m.Space = 0
			m.Text = ""
			return nil
		}
		return ErrInvalidMessage
	}

	var rawMsg map[string]interface{}
	if err := json.Unmarshal(data, &rawMsg); err != nil {
		return ErrInvalidMessage
	}

	chat, ok := rawMsg["ChatMsg"]
	if ok {
		m.MsgType = MsgTypeChat
		data, ok := chat.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		text, ok := data["text"]
		if !ok {
			return ErrInvalidMessage
		}
		textString, ok := text.(string)
		if !ok {
			return ErrInvalidMessage
		}
		m.Text = textString
		m.Space = 0
		return nil
	}

	move, ok := rawMsg["Move"]
	if ok {
		m.MsgType = MsgTypeMove
		data, ok := move.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		space, ok := data["space"]
		if !ok {
			return ErrInvalidMessage
		}
		spaceFloat, ok := space.(float64)
		if !ok {
			return ErrInvalidMessage
		}
		m.Space = int(spaceFloat)
		m.Text = ""
		return nil
	}

	changeName, ok := rawMsg["ChangeName"]
	if ok {
		m.MsgType = MsgTypeChangeName
		data, ok := changeName.(map[string]interface{})
		if !ok {
			return ErrInvalidMessage
		}
		name, ok := data["new_name"]
		if !ok {
			return ErrInvalidMessage
		}
		nameString, ok := name.(string)
		if !ok {
			return ErrInvalidMessage
		}
		m.Text = nameString
		m.Space = 0
		return nil
	}

	return ErrInvalidMessage
}

type JoinedGameMsg struct {
	JoinedGame JoinedGameInner `json:"JoinedGame"`
}

type JoinedGameInner struct {
	Token    string   `json:"token"`
	PlayerId PlayerId `json:"player_id"`
	State    *State   `json:"state"`
}

type GameStateMsg struct {
	GameState *State `json:"GameState"`
}

type ErrorMsg struct {
	Error string `json:"Error"`
}

func NewJoinedGameMsg(token string, playerId PlayerId, state *State) JoinedGameMsg {
	return JoinedGameMsg{
		JoinedGame: struct {
			Token    string   `json:"token"`
			PlayerId PlayerId `json:"player_id"`
			State    *State   `json:"state"`
		}{
			Token:    token,
			PlayerId: playerId,
			State:    state,
		},
	}
}

func NewGameStateMsg(state *State) GameStateMsg {
	return GameStateMsg{
		GameState: state,
	}
}

func NewErrorMsg(errorMsg string) ErrorMsg {
	return ErrorMsg{
		Error: errorMsg,
	}
}
