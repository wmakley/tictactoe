# Websocket Tic-Tac-Toe Svelte Frontend

The best and only frontend for my educational Tic-Tac-Toe backends.

Currently setup to deploy to Vercel (also educational, since it's all the rage currently).

Communication with backend requires CORS to be setup.

## Dev Setup

| Tool | Version |
| ---- | ------- |
| node | 18.15.0 |
| pnpm | 8.3.1 |

```sh
pnpm install
pnpm run dev
```

## Production Build

```sh
pnpm run build
```

## Deployment

Deployment of this repo is automatic from git, but for personal use, you can
deploy manually with:

```sh
pnpm -g install vercel
vercel
```
