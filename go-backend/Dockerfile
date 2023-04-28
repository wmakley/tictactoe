FROM golang:1.19.1 AS build

# Set destination for COPY
WORKDIR /app

# Download Go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code. Note the slash at the end, as explained in
# https://docs.docker.com/engine/reference/builder/#copy
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o /tictactoe


FROM gcr.io/distroless/base-debian11 AS prod

WORKDIR /

COPY --from=build /tictactoe /tictactoe

EXPOSE 3000

USER nonroot:nonroot

ENV FRONTEND_URL "https://svelte-frontend-mu.vercel.app/"

ENTRYPOINT ["/tictactoe"]
