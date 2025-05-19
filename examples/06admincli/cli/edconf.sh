#/bin/bash
PW="${MSERVE_PW:-admin}"
ADDR="${MSERVE_ADDR:-localhost:5000}"
echo "h:hopen \`:$ADDR:admin:$PW; -1 .Q.s h ($#+1) # (\"${0##*/}\"; \"$1\"; \"$2\"; \"$3\"; \"$4\"); exit 0" | q
