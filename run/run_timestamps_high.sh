#!/usr/bin/env bash
# Usage : ./run_timestamps.sh timestamp.txt
# Chaque ligne de timestamp.txt contient un timestamp (ex: 1762267200)
# Le script appelle : ./synchro_wadaco.sh <timestamp> 10
# et passe à la suivante uniquement après la fin de la précédente.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <fichier_timestamp.txt>"
  exit 1
fi

FILE="$1"
NB_REQ=5000

if [ ! -f "$FILE" ]; then
  echo "[ERREUR] Fichier introuvable : $FILE"
  exit 2
fi

# Lecture du fichier ligne par ligne
while IFS= read -r ts; do
  # Ignore les lignes vides ou commentées (#)
  if [[ -z "$ts" || "$ts" =~ ^# ]]; then
    continue
  fi

  echo "===================================================="
  echo "[INFO] Lancement de ./run_flamethrower.sh $ts 20 500 500 10"
  echo "----------------------------------------------------"

  #./synchro_wadaco.sh "$ts" 10
  ./run_flamethrower_high.sh "$ts" 1 "$NB_REQ" 0 20
  
  NB_REQ=$((NB_REQ + 5000))
  
  echo "----------------------------------------------------"
  echo "[INFO] Tâche terminée pour timestamp $ts."
  echo
done < "$FILE"

echo "[INFO] Toutes les tâches sont terminées."
