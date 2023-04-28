.PHONY: all
all: release js

.PHONY: deploy
deploy: js
	fly deploy

.PHONY: release
release:
	cargo build --release

.PHONY: docker-image
docker-image:
	docker build -t tictactoe-rs:latest .

dev:
	RUST_LOG="info,tictactoe_rs=trace,tower_http=trace" cargo run
