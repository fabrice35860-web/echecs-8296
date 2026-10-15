#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie qu'aucun message du panneau ne deborde de sa largeur.

Le panneau n'offre que PAN_LT colonnes au texte courant (52 a 79). Un
message plus long ne se tronque pas : il continue sur la ligne suivante,
colonne 0, c'est-a-dire par-dessus l'echiquier. Le defaut est discret --
une coordonnee de rangee remplacee par une lettre -- et ce controle-la
coute moins cher que de le chercher a l'oeil.

Les marqueurs d'accent (.byte ACC_*) comptent pour un caractere, comme a
l'affichage.

Usage :  python3 outils/verifier_textes.py
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(RACINE, "donnees.asm")

# Les textes qui passent par message / message2, et ceux du panneau.
PREFIXES = ("t_m_", "t_note_")


def longueurs(chemin):
    """Associe a chaque label sa longueur en caracteres affiches."""
    resultat = {}
    courant = None
    with open(chemin) as f:
        for ligne in f:
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s", ligne)
            if m:
                courant = m.group(1)
                if courant not in resultat:
                    resultat[courant] = 0
            if courant is None:
                continue
            for texte in re.findall(r'\.text\s+"([^"]*)"', ligne):
                resultat[courant] += len(texte)
            for octet in re.findall(r"\.byte\s+(.+)", ligne):
                for valeur in octet.split(","):
                    valeur = valeur.split(";")[0].strip()
                    if valeur.startswith("ACC_"):
                        resultat[courant] += 1
                    elif valeur == "$27":       # apostrophe
                        resultat[courant] += 1
                    elif valeur == "0":
                        courant = None          # fin de chaine
                        break
    return resultat


def main():
    largeur = None
    with open(os.path.join(RACINE, "constantes.asm")) as f:
        for ligne in f:
            m = re.match(r"^PAN_LT\s*=\s*(\d+)", ligne)
            if m:
                largeur = int(m.group(1))
    if largeur is None:
        print("PAN_LT introuvable dans constantes.asm")
        return 1

    trop_longs = []
    for label, taille in sorted(longueurs(SOURCE).items()):
        if not label.startswith(PREFIXES):
            continue
        if taille > largeur:
            trop_longs.append((label, taille))
    for label, taille in trop_longs:
        print("ECHEC %-18s %d caracteres pour %d colonnes"
              % (label, taille, largeur))
    if not trop_longs:
        print("ok     aucun message ne deborde du panneau (%d colonnes)"
              % largeur)
    return 1 if trop_longs else 0


if __name__ == "__main__":
    sys.exit(main())
