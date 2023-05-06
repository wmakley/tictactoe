package go_stress_tester

import (
	"context"
	"nhooyr.io/websocket"
	"time"
)

func main() {
	conn, err := (func() (*websocket.Conn, error) {
		ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
		defer cancel()

		c, _, err := websocket.Dial(ctx, "ws://localhost:3000/ws", nil)
		return c, err
	})()
	if err != nil {
		panic(err)
	}
	defer func(conn *websocket.Conn) {
		err := conn.Close(websocket.StatusInternalError, "the sky is falling")
		if err != nil {
			panic(err)
		}
	}(conn)

	c.Read(ctx)
}

type Client struct {
	conn *websocket.Conn
}

func NewClient() (*Client, error) {
	conn, err := (func() (*websocket.Conn, error) {
		ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
		defer cancel()

		c, _, err := websocket.Dial(ctx, "ws://localhost:3000/ws", nil)
		return c, err
	})()
	if err != nil {
		panic(err)
	}
	defer func(conn *websocket.Conn) {
		err := conn.Close(websocket.StatusInternalError, "the sky is falling")
		if err != nil {
			panic(err)
		}
	}(conn)

	return &Client{
		conn: conn,
	}, nil
}
