# Tic-Tac-Toe Stress Tester

Program to open an arbitrary number of connections to a running
Tic-Tac-Toe backend and attempt to play each game to completion
as fast as possible.

* Supports TLS connections.
* Currently each game plays out the exact same.

Calculating more statistics would be useful, like bucketing
latencies into "high", "medium", "low" - that sort of thing.

## Usage

`cargo run HOSTNAME NUMBER`

Example:

```sh
cargo run ws://localhost:3000/ws 10
```

Where the host name may be replaced with any running server,
and "10" may be replaced with the number of games to play.

## Docker Image

Portable docker image is useful for running on VPS.

Build:

```sh
make docker-image
```

Example usage:

```sh
IMAGE=tictactoe-stress-tester:latest
docker run -it --rm --name stress-test $IMAGE ws://localhost:3000/ws 100
```
