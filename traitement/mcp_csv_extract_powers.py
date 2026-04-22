#!/usr/bin/env python3
import sys
import pandas as pd
from datetime import datetime

'''
def datetime_to_timestamp(ts):
    # Format: 2025-11-04T17:54:01.144691
    return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%f").timestamp()
'''
def datetime_to_timestamp(ts):
    try:
        return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%f").timestamp()
    except ValueError:
        return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S").timestamp()


def main():
    # python3 <fichier python> <fichier csv slots> <fichier csv wattmètre> <outfile name>
    slots_file = sys.argv[1]
    mcp_file = sys.argv[2]
    outfile = sys.argv[3]

    # Charger CSV (séparateur virgule par défaut)
    slots = pd.read_csv(slots_file)
    mcp = pd.read_csv(mcp_file)

    # Convertir timestamp mcp
    mcp_time = [datetime_to_timestamp(ts) for ts in mcp["timestamp"]]
    mcp_power = list(mcp["active_power (W)"])

    # Initialiser les nouvelles colonnes
    pw_cumul = [0.0] * len(slots)
    nb_data_wattmeter = [0] * len(slots)
    pw_myenne = [0.0] * len(slots)
    pw_var = [0.0] * len(slots)

    # Extraction des colonnes slots en listes
    slot_begin = list(slots["time_begin"])
    slot_end   = list(slots["time_end"])

    # Pour chaque ligne de slots : 
    # Sortir les timestamps begin et end pour chaque numéro de slot
        # Initialiser tbegin et tend ; Initialiser Pw_cumulatif à 0
            # Pour chaque ligne de csv : 
                # Si t<tbegin : on passe
                # Si t>=tbegin et t<=tend : on prend sa puissance et on l'ajoute au Pw_cumulatif
                # Si t>tend : on ajoute Pw_cumulatif à la ligne du slot, on prend le tbegin et le tend suivant, on réinitialise Pw_cumulatif
    slot_idx = 0
    offset = 0.01
    tbegin = slot_begin[slot_idx] - offset
    tend   = slot_end[slot_idx]   + offset
    pw_sum = 0.0
    pw_square_sum = 0.0
    nb_data_w = 0

    for data in range(len(mcp_time)):
            t = mcp_time[data]

            # Si t < tbegin : on passe
            if t < tbegin:
                continue

            # Si t >= tbegin et t <= tend : on ajoute la puissance
            if t <= tend:
                pw_sum += mcp_power[data]
                pw_square_sum += mcp_power[data] ** 2
                nb_data_w += 1
                continue

            if t > tend:
                pw_cumul[slot_idx] = pw_sum
                pw_myenne[slot_idx] = pw_sum / nb_data_w # Calcul de la moyenne de la puissance du slot
                pw_var[slot_idx] = (pw_square_sum / nb_data_w) - (pw_sum / nb_data_w) ** 2 # Calcul de la variance de la puissance du slot
                
                nb_data_wattmeter[slot_idx] = nb_data_w
                slot_idx += 1

                if slot_idx >= len(slots):
                    break  # On a rempli tous les slots

                tbegin = slot_begin[slot_idx] - offset
                tend   = slot_end[slot_idx]   + offset
                
                pw_sum = 0.0
                pw_square_sum = 0.0
                nb_data_w = 0
                
                continue
        
    # A la fin, on met tout le beau tableau dans un csv
    # Ajouter la colonne dans le dataframe
    slots["cumulative_power"] = pw_cumul
    slots["mean_power"] = pw_myenne
    slots["var_power"] = pw_var
    slots["nb_data_wattmeter_collected"] = nb_data_wattmeter

    # Export CSV final
    slots.to_csv(outfile, index=False)
    print(f"[OK] Résultat écrit dans {outfile}")
                

if __name__ == "__main__":
    main()
