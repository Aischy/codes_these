#!/bin/bash

set -euo pipefail
set -x

# =========================
# Arguments
# =========================
src_folder="$1"
dst_folder="$2"
final_file="$3"

# =========================
# Chargement fichier de config
# =========================
CONFIG_FILE="traitement.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Fichier de config introuvable : $CONFIG_FILE"
    exit 1
fi

# charge les variables
source "$CONFIG_FILE"

# =========================
# Vérif existence fichier de traitement des pcap
# =========================
if [[ ! -x "$PCAP_PROCESSOR" ]]; then
        echo "❌ Exécutable introuvable ou non exécutable : $PCAP_PROCESSOR"
        exit 1
    fi

# =========================
# Création du dossier destination
# =========================
if [[ -e "$dst_folder" ]]; then
    echo "❌ Erreur : le dossier de sortie '$dst_folder' existe déjà"
    exit 1
fi

mkdir -p "$dst_folder"

# =========================
# Fonction utilitaire
# =========================
# Convertit YYYYMMDD_HHMMSS -> timestamp unix
to_epoch() {
    date -d "${1:0:8} ${1:9:2}:${1:11:2}:${1:13:2}" +%s
}

# =========================
# Index des CSV
# =========================
declare -A csv_map

for csv in "$src_folder"/mcp_capture_*.csv; do
    base=$(basename "$csv")
    ts=${base#mcp_capture_}
    ts=${ts%.csv}
    epoch=$(to_epoch "$ts")
    csv_map["$epoch"]="$csv"
done

# =========================
# Matching pcap ↔ csv
# =========================
pairs=()

for pcap in "$src_folder"/capture_*.pcap; do
    base=$(basename "$pcap")
    ts=${base#capture_}
    ts=${ts%.pcap}
    epoch=$(to_epoch "$ts")

    match=""

    # exact match
    if [[ -n "${csv_map[$epoch]:-}" ]]; then
        match="${csv_map[$epoch]}"
    # +1 sec
    elif [[ -n "${csv_map[$((epoch+1))]:-}" ]]; then
        match="${csv_map[$((epoch+1))]}"
    # -1 sec
    elif [[ -n "${csv_map[$((epoch-1))]:-}" ]]; then
        match="${csv_map[$((epoch-1))]}"
    fi

    if [[ -z "$match" ]]; then
        echo "⚠️  Pas de CSV pour $pcap"
        continue
    fi

    pairs+=("$pcap|$match")
done

N=${#pairs[@]}

if [[ "$N" -eq 0 ]]; then
    echo "❌ Aucun couple trouvé"
    exit 1
fi

echo "✅ $N couples trouvés"

# =========================
# Worker
# =========================
echo "1"
process_one() {
    local idx="$1"
    local pcap="$2"
    local csv="$3"

    local out_name="repet${idx}.csv"

    echo "▶️  [$idx] Processing $(basename "$pcap")"

    "$PCAP_PROCESSOR" "$pcap" "$IP_CLIENT" "$IP_RSV" "$out_name"

    # nettoyage
    mv "prov_${out_name}" "trash/prov_${out_name}"

    # déplacement résultat pcap
    mv "$out_name" "$dst_folder/$out_name"

    # copie csv énergie
    cp "$csv" "$dst_folder/${idx}.csv"
}
echo "2"

export -f process_one
export dst_folder
export PCAP_PROCESSOR
export IP_SRC
export IP_DST

echo "3"

# =========================
# Parallélisation
# =========================
i=0
for pair in "${pairs[@]}"; do
    ((++i))
    echo "4"
    IFS="|" read -r pcap csv <<< "$pair"

    process_one "$i" "$pcap" "$csv" &
    jobs -l

    echo "5"

    # limite parallèle
    if (( $(jobs -r | wc -l) >= $NB_PARALLEL )); then
        wait -n
    fi

    echo "6"
done

wait
echo "7"
# =========================
# Final
# =========================
echo "🚀 Construction finale"

python3 build_all_repet.py "$dst_folder/" "$final_file" "$N"

echo "8"

echo "✅ Terminé"