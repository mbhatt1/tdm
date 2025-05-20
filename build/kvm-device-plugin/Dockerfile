FROM golang:1.24 as builder

WORKDIR /app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o kvm-device-plugin ./cmd/kvm-device-plugin

FROM alpine:3.18

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/kvm-device-plugin /app/kvm-device-plugin

ENTRYPOINT ["/app/kvm-device-plugin"]