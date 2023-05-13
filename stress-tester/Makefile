release:
	cargo build --release

local-test:
	cargo run -- ws://localhost:3000/ws 100

docker-image:
	docker build -t tictactoe-stress-tester:latest .

.PHONY: release local-test docker-image
