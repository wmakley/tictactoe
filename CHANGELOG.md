# Changelog for all projects

## 2023-04-30

### Svelte Frontend
* Slightly improve appearance of game board.

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
