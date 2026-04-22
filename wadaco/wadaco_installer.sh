#!/bin/bash

set -e  # Arrête le script en cas d'erreur

# Vérifie que le script est lancé avec les droits root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté avec sudo ou en tant que root." 
   exit 1
fi

# Installe les dépendances système
echo "[*] Installation des paquets nécessaires..."
apt update
apt install -y python3 python3-pip python3-venv libusb-1.0-0-dev sshpass

# Crée l’environnement virtuel Python (dans le dossier courant)
echo "[*] Création de l'environnement virtuel Python..."
sudo -u "$SUDO_USER" python3 -m venv venv

# Active l’environnement virtuel et installe le paquet .whl
echo "[*] Activation de l'environnement virtuel et installation du paquet EasyMCP2221..."
# Remplacer ce chemin par le vrai chemin de ton fichier .whl si nécessaire
WHEEL_PATH="/chemin/vers/dossier/EasyMCP2221-*.whl"

# Vérifie si le fichier existe
if ls $WHEEL_PATH 1> /dev/null 2>&1; then
    sudo -u "$SUDO_USER" bash -c "source venv/bin/activate && pip install $WHEEL_PATH"
else
    echo "[!] Fichier .whl introuvable à l'emplacement : $WHEEL_PATH"
    exit 1
fi

# Ajoute la règle udev
echo "[*] Écriture de la règle udev..."
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04d8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/99-mcp.rules

# Recharge les règles udev
echo "[*] Rechargement des règles udev..."
udevadm control --reload-rules
udevadm trigger

# Rends le script wadaco exécutable
echo "[*] Rend le script wadaco exécutable..."
chmod +x /home/$SUDO_USER/WaDaCo-terminal/wadaco

# Ajoute WaDaCo-terminal au PATH
echo "[*] Ajout de WaDaCo-terminal au PATH de .bashrc..."
echo 'export PATH="$HOME/WaDaCo-terminal:$PATH"' >> /home/$SUDO_USER/.bashrc

# Recharge le bashrc
echo "[*] Rechargement de .bashrc..."
sudo -u "$SUDO_USER" bash -c "source /home/$SUDO_USER/.bashrc"

echo "[✔] Installation terminée avec succès."
