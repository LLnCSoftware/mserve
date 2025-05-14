#!/bin/bash

# Check arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <pattern>"
  exit 1
fi

PATTERN="$1"

# Host and port from MSERVE_ADDR or default
ADDR="${MSERVE_ADDR:-localhost:5000}"
HOST=$(echo "$ADDR" | cut -d':' -f1)
PORT=$(echo "$ADDR" | cut -d':' -f2)

# Compose and send the command via netcat
echo "h:hopen \`:$ADDR; -1 each  h (\"getRule\";\"$PATTERN\"); exit 0" | q
