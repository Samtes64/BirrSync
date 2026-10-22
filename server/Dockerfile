# Build Stage
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /birrsync-server .

# Production Minimal Stage
FROM alpine:3.21
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /birrsync-server .
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1
CMD ["./birrsync-server"]
