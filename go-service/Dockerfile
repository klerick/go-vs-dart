FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY go.mod main.go ./
RUN go mod tidy && CGO_ENABLED=0 go build -ldflags="-s -w" -o server .

FROM scratch
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]