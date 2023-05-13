# Changelog for all projects

## 2023-05-13
### Stress Tester
* Fix TLS connection not working.
* Added CA certs to docker image.

## 2023-05-12
### Stress Tester
* Collect even more interesting and useful stats.
* Delete unused struct fields.
* Dockerize it.

### Go Backend
* Wait 1 minute to delete empty games.
* Generate longer default game IDs of 7 chars (same as Rust backend).

## 2023-05-11
### Go Backend
* Fix major race condition, where not all players were guaranteed to receive
  all state updates if they played too fast.

### Stress Tester
* Fix logic error where it didn't properly wait for game to be full
  before trying to take a turn.
* Comment a bunch of print statements so stress test results are meaningful
  again, after debugging the Go server.

### Rust Backend
* Set log level to INFO in production, since debug logging was found
  to substantially increase latency.

## 2023-05-10
### Stress Tester
* Calculate average server latency (time to respond to player actions) for the run.
* More printout and error handling improvements.

### Rust Backend
* Explicitly handle unexpected socket messages and socket errors
  by disconnecting, as in testing these errors seem to be entirely
  connection resets.
* No need to log ping pong.

## 2023-05-07
### Stress Tester
* Can now play a full game to completion!
* Can now play an arbitrary number of games at once. Already exposing issues.

## 2023-05-04

### Rust Backend
* Refactoring of how players are removed from games and empty games
  are cleaned up to be "nicer" and more foolproof.
* Delete unnecessry "Pong" code.
* Release read lock on watch channel sooner.

## 2023-05-01

### Stress Tester
* Lots of progress. Two players may now join the game, and there are some assertions.

### Rust Backend
* Fixed initial player ID being 0 instead of 1.

## 2023-04-30

### Svelte Frontend
* Slightly improve appearance of game board.
* Add Makefile.

### Go Backend
* Add Max-Age 3600 header to go backend CORS OPTIONS handler.

### Rust Backend
* Rust backend OPTIONS handler now returns headers instead of body.

## 2023-04-28

* Added README.md to root and subprojects.
* Add CHANGELOG.md.
* Add root .editorconfig

### Go Backend
* Remove "sync.Locker" interface from go backend server state interface.
* Add OPTIONS, robots.txt, and frontend redirect support.
* Add Dockerfile.
* Deploy to fly.io.

### Rust Backend
* Remove static file server.
* Add CORS support.
* Add support for redirecting to FRONTEND_URL.
* Setup fly.io config to deploy as a new app.
* Upgrade to Fly V2

### Svelte Frontend
* Allow user to pick a backend via dropdown.
