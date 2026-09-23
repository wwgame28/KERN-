#!/bin/sh
set -eu

STATE_DIR="${OPENCLAW_STATE_DIR:-/data}"
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$STATE_DIR/openclaw.json}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$STATE_DIR/workspace}"
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"

if [ ! -s "$CONFIG_PATH" ]; then
  cp /opt/openclaw/openclaw.json "$CONFIG_PATH"
fi

exec node /app/dist/index.js gateway --bind lan --port "$PORT"
