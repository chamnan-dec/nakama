# Stage 1: Build Nakama binary
FROM golang:1.25.0-bookworm AS builder

WORKDIR /app
COPY . /app/build
WORKDIR /app/build

# build Nakama binary
RUN apt-get update && apt-get install -y gcc libc6-dev \
    && go build -o /nakama/nakama .

# Stage 2: Run Nakama
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates tzdata tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /nakama
COPY --from=builder /nakama/nakama /nakama/nakama

# --- add entrypoint script ---
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
set -e

echo ">>> DATABASE_URL: $DATABASE_URL"
echo ">>> Running database migration..."
/nakama/nakama migrate up --database.address "$DATABASE_URL"

echo ">>> Starting Nakama server..."
exec /nakama/nakama \
  --name nakama1 \
  --database.address "$DATABASE_URL" \
  --logger.level DEBUG \
  --session.token_expiry_sec 7200 \
  --metrics.prometheus_port 9100
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 7349 7350 7351 9100

ENTRYPOINT ["/entrypoint.sh"]