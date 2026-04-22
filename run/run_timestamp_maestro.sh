#!/usr/bin/env bash
# Script de capture réseau planifiée à partir d'une liste de timestamps

set -e

TIMESTAMP_FILE="timestamps.txt"
DURATION=60
INTERFACE="enxa0cec85e8e17"

OUTPUT_DIR="/tmp"
FINAL_DIR="$HOME/captures"

USER_NAME=$(whoami)
GROUP_NAME=$(id -gn "$USER_NAME")

mkdir -p "$FINAL_DIR"

# 🔐 Demande du mot de passe sudo UNE FOIS au début
echo "[INFO] Authentification sudo requise..."
sudo -k
sudo -v

# Maintient le ticket sudo actif en arrière-plan
( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

# Nettoyage à la sortie
trap 'kill $SUDO_KEEPALIVE_PID' EXIT

echo "[INFO] Lecture des timestamps depuis $TIMESTAMP_FILE"

while IFS= read -r TIMESTAMP || [ -n "$TIMESTAMP" ]; do

    # Skip lignes vides
    [[ -z "$TIMESTAMP" ]] && continue

    DATE_STR=$(date -d @"$TIMESTAMP" '+%Y%m%d_%H%M%S')
    OUTPUT_FILE="${OUTPUT_DIR}/capture_${DATE_STR}.pcap"
    FINAL_FILE="${FINAL_DIR}/capture_${DATE_STR}.pcap"

    CURRENT_TIME=$(date +%s)

    echo "--------------------------------------------------"
    echo "[INFO] Prochaine capture à $(date -d @"$TIMESTAMP")"

    if [ "$CURRENT_TIME" -lt "$TIMESTAMP" ]; then
        SLEEP_TIME=$((TIMESTAMP - CURRENT_TIME))
        echo "[INFO] Attente de $SLEEP_TIME secondes..."
        sleep "$SLEEP_TIME"
    else
        echo "[WARN] Timestamp déjà passé, capture immédiate."
    fi

    echo "[INFO] Capture en cours (${DURATION}s)..."

    sudo tshark -i "$INTERFACE" -a duration:"$DURATION" -w "$OUTPUT_FILE" > /dev/null 2>&1 || {
        echo "[ERREUR] Échec de tshark pour timestamp $TIMESTAMP"
        continue
    }

    if [ -f "$OUTPUT_FILE" ]; then
        echo "[INFO] Capture OK : $(du -h "$OUTPUT_FILE" | cut -f1)"

        sudo cp "$OUTPUT_FILE" "$FINAL_FILE"
        sudo chown "$USER_NAME:$GROUP_NAME" "$FINAL_FILE"
        sudo chmod 644 "$FINAL_FILE"
        sudo rm -f "$OUTPUT_FILE"

        echo "[INFO] Sauvegardé dans $FINAL_FILE"
    else
        echo "[ERREUR] Fichier absent après capture"
    fi

done < "$TIMESTAMP_FILE"

echo "[OK] Toutes les captures sont terminées."
