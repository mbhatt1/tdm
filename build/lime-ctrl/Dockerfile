FROM golang:1.24 as builder

WORKDIR /app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o lime-ctrl ./cmd/lime-ctrl

FROM alpine:3.18

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/lime-ctrl /app/lime-ctrl

ENTRYPOINT ["/app/lime-ctrl"]