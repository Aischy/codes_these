#!/usr/bin/env bash

set -euo pipefail

# Vérification des arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <timestamp_depart> <ecart_minutes> <nombre>"
  exit 1
fi

START_TS="$1"
DELTA_SEC="$2"
COUNT="$3"

# Validation basique (évite de faire n’importe quoi)
if ! [[ "$START_TS" =~ ^[0-9]+$ && "$DELTA_SEC" =~ ^[0-9]+$ && "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "[ERREUR] Tous les arguments doivent être des entiers positifs"
  exit 2
fi

OUTPUT_FILE="timestamps.txt"

# Écrase le fichier
: > "$OUTPUT_FILE"

current_ts="$START_TS"

for ((i=0; i<COUNT; i++)); do
  echo "$current_ts" >> "$OUTPUT_FILE"
  current_ts=$((current_ts + DELTA_SEC))
done

echo "[INFO] $COUNT timestamps générés dans $OUTPUT_FILE"
