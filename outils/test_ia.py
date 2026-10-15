#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie ce que l'adversaire trouve sur des positions sans ambiguite.

Lance test_ia.prg dans VICE, relit l'ecran et compare chaque coup a la
liste des coups acceptables (outils/ia_attendu.json, refaite par
outils/generer_ia.py).

Usage :  python3 outils/test_ia.py [-v] [--cycles N]

Un echec ici vient de la recherche ou de l'evaluation ; le generateur de
coups, lui, est juge par outils/test_perft.py.
"""

import json
import os
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from lire_ecran import lire_grille, symbole          # noqa: E402

PRG = os.path.join(RACINE, "test_ia.prg")
ATTENDU = os.path.join(RACINE, "outils", "ia_attendu.json")
CYCLES = 400000000


def main():
    bavard = "-v" in sys.argv
    cycles = CYCLES
    if "--cycles" in sys.argv:
        cycles = int(sys.argv[sys.argv.index("--cycles") + 1])
    if not os.path.exists(PRG):
        print("test_ia.prg absent : lancer d'abord "
              "64tass --cbm-prg -o test_ia.prg test_ia.asm")
        return 1
    with open(ATTENDU) as f:
        attendu = json.load(f)

    with tempfile.TemporaryDirectory() as dossier:
        image = os.path.join(dossier, "ia.png")
        cmd = ["xpet", "-model", "8296", "-autostart", PRG,
               "-limitcycles", str(cycles), "-exitscreenshot", image,
               "-warp", "+sound"]
        subprocess.run(cmd, capture_output=True, timeout=1800)
        if not os.path.exists(image):
            print("pas de capture d'ecran : VICE n'a rien rendu")
            return 1
        grille, _ = lire_grille(image)
        lignes = [("".join(symbole(c) for c in l)).rstrip() for l in grille]

    if bavard:
        for i, ligne in enumerate(lignes):
            if ligne:
                print("%2d| %s" % (i, ligne))

    # Une ligne par position : "<numero> <coup> <score> <noeuds>"
    trouves = {}
    fini = False
    for ligne in lignes:
        if ligne.strip() == "FINI":
            fini = True
            continue
        morceaux = ligne.split()
        if len(morceaux) < 2 or not morceaux[0].isdigit():
            continue
        trouves[int(morceaux[0])] = morceaux[1:]

    echecs = 0
    for i, position in enumerate(attendu, start=1):
        obtenu = trouves.get(i)
        if not obtenu:
            print("ECHEC %-24s rien trouve (essai ecourte ?)"
                  % position["nom"])
            echecs += 1
            continue
        coup = obtenu[0].lower()
        detail = ""
        if len(obtenu) >= 3:
            detail = " (score %s, %s noeuds)" % (obtenu[1], obtenu[2])
        if coup not in position["coups"]:
            print("ECHEC %-24s joue %s ; attendu %s"
                  % (position["nom"], coup.upper(),
                     " ou ".join(c.upper() for c in position["coups"][:6])))
            print("      %s" % position["pourquoi"])
            echecs += 1
        else:
            print("ok    %-24s %s%s"
                  % (position["nom"], coup.upper(), detail))
    if not fini:
        print("le programme n'a pas affiche FINI : essai ecourte")
    print("%d echec(s) sur %d position(s)" % (echecs, len(attendu)))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
