#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validation du generateur de coups : perft dans VICE contre python-chess.

Assemble et lance perft.prg, relit l'ecran produit et compare chaque
nombre a celui qu'attend l'oracle (outils/perft_attendu.json, refait par
outils/generer_perft.py).

Usage :  python3 outils/test_perft.py [-v] [--cycles N]

Le programme 6502 explore quelques centaines de milliers de positions :
comptez une a deux minutes en warp. L'option --cycles sert a ecourter
l'essai pendant une mise au point ; les lignes incompletes sont alors
signalees comme telles, pas comme des erreurs.
"""

import json
import os
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from lire_ecran import lire_grille, symbole          # noqa: E402
from vice import ROMS_STANDARD                       # noqa: E402

PRG = os.path.join(RACINE, "perft.prg")
ATTENDU = os.path.join(RACINE, "outils", "perft_attendu.json")
CYCLES = 12000000000


def lignes_ecran(image):
    grille, _ = lire_grille(image)
    return [("".join(symbole(c) for c in ligne)).rstrip() for ligne in grille]


def main():
    bavard = "-v" in sys.argv
    cycles = CYCLES
    if "--cycles" in sys.argv:
        cycles = int(sys.argv[sys.argv.index("--cycles") + 1])
    if not os.path.exists(PRG):
        print("perft.prg absent : lancer d'abord "
              "64tass --cbm-prg -o perft.prg perft.asm")
        return 1
    with open(ATTENDU) as f:
        attendu = json.load(f)

    with tempfile.TemporaryDirectory() as dossier:
        image = os.path.join(dossier, "perft.png")
        cmd = ["xpet", "-model", "8296"] + ROMS_STANDARD + [ "-autostart", PRG,
               "-limitcycles", str(cycles), "-exitscreenshot", image,
               "-warp", "+sound"]
        subprocess.run(cmd, capture_output=True, timeout=3600)
        if not os.path.exists(image):
            print("pas de capture d'ecran : VICE n'a rien rendu")
            return 1
        lignes = lignes_ecran(image)

    if bavard:
        for i, ligne in enumerate(lignes):
            if ligne:
                print("%2d| %s" % (i, ligne))

    # Une ligne par position : "<numero> <perft 1> <perft 2> ..."
    resultats = {}
    fini = False
    for ligne in lignes:
        if ligne.strip() == "FINI":
            fini = True
            continue
        morceaux = ligne.split()
        if len(morceaux) < 2 or not all(m.isdigit() for m in morceaux):
            continue
        resultats[int(morceaux[0])] = [int(m) for m in morceaux[1:]]

    echecs = 0
    incomplets = 0
    for i, position in enumerate(attendu, start=1):
        obtenus = resultats.get(i, [])
        for prof, valeur in enumerate(position["perft"], start=1):
            if prof > len(obtenus):
                print("     %-11s perft(%d) : pas calcule (essai ecourte ?)"
                      % (position["nom"], prof))
                incomplets += 1
                continue
            if obtenus[prof - 1] != valeur:
                print("ECHEC %-11s perft(%d) = %d au lieu de %d"
                      % (position["nom"], prof, obtenus[prof - 1], valeur))
                echecs += 1
            else:
                print("ok    %-11s perft(%d) = %d"
                      % (position["nom"], prof, valeur))
    if not fini:
        print("le programme n'a pas affiche FINI : essai ecourte ou "
              "interrompu")
    print("%d ecart(s), %d non calcule(s)" % (echecs, incomplets))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
