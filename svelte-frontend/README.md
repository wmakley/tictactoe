# Websocket Tic-Tac-Toe Svelte Frontend

The best and only frontend for my educational Tic-Tac-Toe backends.

Currently setup to deploy to Vercel (also educational, since it's all the rage currently).

Communication with backend requires CORS to be setup.

## Dev Setup

| Tool | Version |
| ---- | ------- |
| node | 18.15.0 |
| pnpm | 8.3.1 |

Requires pnpm.

```sh
pnpm install
pnpm run dev
```

## Production Build

```sh
pnpm run build
```

## TODO:

* Implement ability to switch backends.
* Add CORS support to backends.
