FROM golang:1.24 as builder

WORKDIR /app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o flintlock ./cmd/flintlock

FROM alpine:3.18

RUN apk --no-cache add ca-certificates python3 bash

WORKDIR /app

COPY --from=builder /app/flintlock /app/flintlock

# Create directory for flintlock data
RUN mkdir -p /var/lib/flintlock/microvms

VOLUME /var/lib/flintlock

ENTRYPOINT ["/app/flintlock"]