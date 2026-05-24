# Dockerfile for Go Applications
# Prerequisites: go.mod and go.sum at build context root
# Customize: {{GO_VERSION}}, {{PORT}}, {{BINARY_NAME}}, {{MAIN_PATH}}
# Last verified: Docker 27.x, Go 1.22+

# Stage 1: Build
FROM golang:{{GO_VERSION}}-alpine AS builder
WORKDIR /app
RUN apk add --no-cache ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w -X main.version=$VERSION" \
    -o /app/{{BINARY_NAME}} {{MAIN_PATH}}

# Stage 2: Runtime
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/{{BINARY_NAME}} /{{BINARY_NAME}}
USER 1000:1000
EXPOSE {{PORT}}
CMD ["/{{BINARY_NAME}}"]
