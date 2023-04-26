# tictactoe-rs

Tic-Tac-Toe Rust and Svelte websockets experiment.

## Backend Setup

As a pre-requisite to compile and run only the server, you must have rust and
cargo installed.

```sh
RUST_LOG="info,tictactoe_rs=trace,tower_http=trace" cargo run
```

Open http://localhost:3000/ in a browser. It should just work! But assets will
not be compiled on the fly. To compile assets, simply run:

```sh
make js
```

## Frontend Development

| Tool | Version |
| ---- | ------- |
| node | 18.15.0 |
| pnpm | 8.1.0 |

Recommend installing using ASDF: https://asdf-vm.com/

```sh
cd svelte
pnpm install
pnpm run dev
```

Open http://localhost:5173/ instead. (The server must still be running on
port 3000 for it to work.)
