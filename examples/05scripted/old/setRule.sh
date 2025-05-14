#!/bin/bash

# Check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <pos> \"rule\" \"phasein\""
  exit 1
fi

POS="$1"
RULE="$2"
PHASEIN="$3"

# Host and port from MSERVE_ADDR or default
ADDR="${MSERVE_ADDR:-localhost:5000}"
HOST=$(echo "$ADDR" | cut -d':' -f1)
PORT=$(echo "$ADDR" | cut -d':' -f2)

# Compose and send the command via netcat
echo "h:hopen \`:$ADDR; -1 h (\"setRule\"; \"$POS\"; \"$RULE\"; \"$PHASEIN\"); exit 0" | q 

