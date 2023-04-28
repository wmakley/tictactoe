SRCS := go.mod go.sum $(shell find . -name *.go)

go-backend: $(SRCS) $(MOD)
	go build .

clean:
	rm go-backend

dev:
	go run .

.PHONY: clean dev
