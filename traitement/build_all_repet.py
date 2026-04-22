import sys
import pandas as pd
import subprocess

def build_all_repet(basedir,concatfile,nbfiles):
    
    dfs = []

    for x in range(1, nbfiles+1):
        filename = f"./{basedir}/repet{x}_with_power.csv"
        df = pd.read_csv(filename)

        # Ajouter la colonne repetition (au début)
        df.insert(0, "repetition", x)

        dfs.append(df)

    # Concaténation
    all_repet = pd.concat(dfs, ignore_index=True)

    # Sauvegarde
    all_repet.to_csv(concatfile, index=False)

    print(f"Fichier {concatfile} créé.")


def run_extract(basedir,nbfiles):
    for x in range(1, nbfiles+1):
        cmd = [
            "python3",
            "./mcp_csv_extract_powers.py",
            f"./{basedir}/repet{x}.csv",
            f"./{basedir}/{x}.csv",
            f"./{basedir}/repet{x}_with_power.csv"
        ]
    
        print("Commande exécutée :", " ".join(cmd))
        subprocess.run(cmd, check=True)



def main():
    basedir = sys.argv[1]
    concatfile = sys.argv[2]
    nbfiles = int(sys.argv[3])
    
    run_extract(basedir,nbfiles)
    build_all_repet(basedir,concatfile,nbfiles)


if __name__ == "__main__":
    main()