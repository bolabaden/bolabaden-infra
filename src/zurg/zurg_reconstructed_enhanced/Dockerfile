# Build stage
FROM golang:1.24-alpine AS builder

# Install build dependencies (CGO toolchain required)
RUN apk add --no-cache git ca-certificates tzdata build-base

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application with exact ldflags from original binary
RUN CGO_ENABLED=1 GOOS=linux go build \
    -ldflags="-s -w -X 'github.com/debridmediamanager/zurg/internal/version.BuiltAt=2024-07-14T09:48:32' -X 'github.com/debridmediamanager/zurg/internal/version.GitCommit=4179c2745b4fb22fcb37f36de27b3daa39f114f0' -X 'github.com/debridmediamanager/zurg/internal/version.Version=v0.9.3-final'" \
    -o zurg \
    ./cmd/zurg

# Final stage - matches original container structure
FROM alpine:3.19

# Install runtime dependencies (matches original container)
RUN apk add --no-cache \
    ca-certificates \
    curl \
    python3 \
    py3-pip \
    tzdata \
    bash \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/zurg /app/zurg

# Copy configuration template
COPY config.yml.example /app/config.yml

# Create healthcheck script (matches original)
RUN echo '#!/bin/bash\ncurl -f http://localhost:9999/health || exit 1' > /app/healthcheck.sh && \
    chmod +x /app/healthcheck.sh

# Create logs directory
RUN mkdir -p /app/logs

# Expose port (matches original)
EXPOSE 9999

# Add healthcheck (matches original container)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /app/healthcheck.sh

# Set entrypoint (matches original)
ENTRYPOINT ["/app/zurg"]
