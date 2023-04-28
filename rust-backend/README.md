# Websocket Tic-Tac-Toe Rust Backend

The OG. Uses Axum, Tokio, and some standard library stuff.

Original version included static file server for frontend, but I am now ripping that out and implementing CORS.

TODO: Finish implementing CORS.

## Development Server

You must have rust and cargo installed, presumably using "rustup".

```sh
RUST_LOG="info,tictactoe_rs=trace,tower_http=trace" cargo run
```

It will listen on port 3000.

## Production Build

```sh
make docker-image
```

Or deploy to fly.io.
