#!/usr/bin/env bash
# run_flamethrower.sh
# Usage:
#   ./run_flamethrower.sh <timestamp> <nb_slots_actifs> <debit_ini> <palier> <duree_idle>
# Exemple:
#   ./run_flamethrower.sh 1734418800 5 100 50 10
#
# Paramètres:
#   timestamp        : timestamp Unix (secondes) auquel commencer (sleep jusqu'à ce timestamp)
#   nb_slots_actifs  : nombre de slots (entier >=1)
#   debit_ini        : débit initial en requêtes par seconde (entier)
#   palier           : palier d'augmentation en rps par slot (entier)
#   duree_idle       : pause en secondes entre actions (entier)
#
# Comportement:
#   - Synchronise l'heure via systemd-timesyncd vers 10.0.10.10
#   - Attend jusqu'au timestamp
#   - Attend duree_idle
#   - Pour chaque slot i de 0 à nb_slots_actifs-1:
#       - calcule rate = debit_ini + i * palier
#       - calcule total = rate * 20
#       - lance flamethrower avec ces paramètres: cible srv1.test.local, type A, resolver 10.0.30.15
#       - attend duree_idle

set -euo pipefail

# --- Vérification des arguments ---
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <timestamp> <nb_slots_actifs> <debit_ini> <palier> <duree_idle>"
  exit 2
fi

TIMESTAMP="$1"
NB_SLOTS="$2"
DEBIT_INI="$3"
PALIER="$4"
DUREE_IDLE="$5"

NTP_SERVER="10.0.10.10"
TARGET="srv1.test.local"
TYPE_RECORD="A"
RESOLVER="10.0.30.15"
# Le facteur 20 demandé pour le nombre total
DUREE_ACTIF=30

# --- Utilitaires ---
timestamp_to_readable() {
  date -d @"$1" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date -u -d @"$1" '+%Y-%m-%d %H:%M:%S UTC'
}

is_integer() {
  [[ "$1" =~ ^-?[0-9]+$ ]]
}

# Validate numeric args
for varname in TIMESTAMP NB_SLOTS DEBIT_INI PALIER DUREE_IDLE; do
  val="${!varname}"
  if ! is_integer "$val"; then
    echo "[ERROR] $varname doit être un entier. Valeur fournie: $val"
    exit 3
  fi
done

if [ "$NB_SLOTS" -le 0 ]; then
  echo "[ERROR] nb_slots_actifs doit être >= 1"
  exit 4
fi

# --- Vérifier que flamethrower existe ---
if ! command -v ./flamethrower/build/flame >/dev/null 2>&1; then
  echo "[ERROR] commande 'flamethrower' introuvable dans le PATH. Installe-la ou donne le chemin complet."
  exit 5
fi

# --- Synchronisation NTP ---
echo "[INFO] $(date +%Y-%m-%d_%H:%M:%S) - Redémarrage de systemd-timesyncd et synchronisation NTP avec $NTP_SERVER..."
# On restart systemd-timesyncd (peut demander sudo)
sudo systemctl restart systemd-timesyncd
# Assure-toi que le daemon est démarré puis configure le serveur NTP si nécessaire
# On force une synchronisation immédiate si timedatectl/chrony/ntp ne sont pas utilisés :
if command -v timedatectl >/dev/null 2>&1; then
  # Sur Ubuntu, timedatectl sync peut être utile (note: timedatectl ne force pas toujours une sync immédiate)
  sudo timedatectl set-ntp true || true
fi

# Optionnel : essayer un one-shot de synchronisation si ntpd/ntpdate présents (silencieux si absents)
if command -v ntpd >/dev/null 2>&1; then
  echo "[INFO] Lancement ntpd -gq pour forcer la sync (si disponible)..."
  sudo ntpd -gq -p "$NTP_SERVER" || echo "[WARN] ntpd -gq a échoué (continuer)..."
elif command -v ntpdate >/dev/null 2>&1; then
  echo "[INFO] Lancement ntpdate (si disponible)..."
  sudo ntpdate -u "$NTP_SERVER" || echo "[WARN] ntpdate a échoué (continuer)..."
else
  echo "[INFO] ntpd/ntpdate non trouvés : on s'en remet à systemd-timesyncd."
fi

echo "[INFO] Synchronisation tentée. Heure actuelle : $(date '+%Y-%m-%d %H:%M:%S %Z')"

# --- Sleep jusqu'au timestamp ---
NOW=$(date +%s)
DELAY=$((TIMESTAMP - NOW))

if [ "$DELAY" -le 0 ]; then
  echo "[WARN] Timestamp $TIMESTAMP ($(timestamp_to_readable "$TIMESTAMP")) est dans le passé ou immédiat. Exécution immédiate."
else
  echo "[INFO] Attente de $DELAY secondes jusqu'à $(timestamp_to_readable "$TIMESTAMP")..."
  # Si sleep est interrompu par un signal, on continue ; utilité : permettre ctrl-c
  sleep "$DELAY"
fi

# --- Pause initiale ---
if [ "$DUREE_IDLE" -gt 0 ]; then
  echo "[INFO] Pause initiale de $DUREE_IDLE secondes..."
  sleep "$DUREE_IDLE"
fi

# --- Boucle des slots ---
echo "[INFO] Début de la boucle sur $NB_SLOTS slots (débit initial $DEBIT_INI rps, palier $PALIER rps, cible $TARGET)..."

for (( slot=0; slot<NB_SLOTS; slot++ )); do
  # Calculs en entier
  RATE=$((DEBIT_INI + slot * PALIER))

  echo "----------------------------------------------------------------"
  echo "[INFO] Slot #$slot - rate=${RATE} rps - début à $(date '+%Y-%m-%d %H:%M:%S %Z')"

  # Exécution : adapte l'appel si les options réelles de flamethrower sont différentes
  if ! ~/flamethrower/build/flame "${RESOLVER}" -Q "${RATE}" -l "${DUREE_ACTIF}" -T "${TYPE_RECORD}" -r "${TARGET}"; then
    echo "[ERROR] Execution de flamethrower échouée pour le slot $slot. Continuation..."
  else
    echo "[INFO] flamethrower terminé pour le slot $slot à $(date '+%Y-%m-%d %H:%M:%S %Z')"
  fi

  # Pause entre slots sauf après le dernier
  if [ $slot -lt $((NB_SLOTS - 1)) ]; then
    echo "[INFO] Pause de $DUREE_IDLE secondes avant le slot suivant..."
    sleep "$DUREE_IDLE"
  fi
done

echo "[INFO] Tous les slots terminés. Fin du script à $(date '+%Y-%m-%d %H:%M:%S %Z')"
exit 0
