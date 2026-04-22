import os
import sys

def rename_files(directory):
    directory = os.path.abspath(directory)

    if not os.path.isdir(directory):
        print("Erreur : dossier invalide")
        return

    # --- Renommage des CSV ---
    csv_files = sorted([f for f in os.listdir(directory) if f.lower().endswith(".csv")])

    print(f"{len(csv_files)} fichiers CSV trouvés.")

    for i, old_name in enumerate(csv_files, start=1):
        new_name = f"{i}.csv"
        old_path = os.path.join(directory, old_name)
        new_path = os.path.join(directory, new_name)
        os.rename(old_path, new_path)

    # --- Renommage des PCAP ---
    pcap_files = sorted([f for f in os.listdir(directory) if f.lower().endswith(".pcap")])

    print(f"{len(pcap_files)} fichiers PCAP trouvés.")

    for i, old_name in enumerate(pcap_files, start=1):
        new_name = f"{i}.pcap"
        old_path = os.path.join(directory, old_name)
        new_path = os.path.join(directory, new_name)
        os.rename(old_path, new_path)

    print("Renommage terminé.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage : python rename.py <dossier>")
        sys.exit(1)

    rename_files(sys.argv[1])
