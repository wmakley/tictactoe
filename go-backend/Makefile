SOURCE := go.mod go.sum $(shell find . -name *.go)

go-backend: $(SOURCE)
	go build .

clean:
	rm go-backend

dev:
	HOST=127.0.0.1 go run .

deploy:
	fly deploy

test:
	go test ./game

.PHONY: clean dev deploy test
