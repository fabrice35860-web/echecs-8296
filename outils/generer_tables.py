#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere donnees_tables.asm : tables de conversion case <-> ecran.

Plateau interne 0x88 : la case de colonne f (0..7) et de rangee g (0..7,
g = 0 pour la rangee 1 des Blancs) porte l'index 16*g + f. Une case est
hors echiquier si et seulement si index AND $88 n'est pas nul, ce qui rend
les tests de bord immediats.

Geometrie ecran (disposition validee sur maquette) : la case se dessine
sur 6 colonnes et 3 lignes. La rangee 8 est en haut, donc la rangee g
occupe la ligne d'ecran y0 = 3 * (7 - g).
    x0 = COL_ECH + 6 * f        y0 = 3 * (7 - g)
    adresse = $8000 + 80 * y0 + x0
"""

import os

ECRAN = 0x8000
LARGEUR = 80
COL_ECH = 2             # premiere colonne de l'echiquier
CASE_L = 6              # largeur d'une case en caracteres
CASE_H = 3              # hauteur d'une case en caracteres


def adresse_case(index):
    """Adresse ecran du coin haut-gauche de la case 0x88, 0 si hors echiquier."""
    if index & 0x88:
        return 0
    f = index & 7
    g = index >> 4
    x0 = COL_ECH + CASE_L * f
    y0 = CASE_H * (7 - g)
    return ECRAN + LARGEUR * y0 + x0


def octets(nom, valeurs, commentaire, par_ligne=16):
    lignes = ["; " + commentaire, nom + ":"]
    for i in range(0, len(valeurs), par_ligne):
        tranche = valeurs[i:i + par_ligne]
        lignes.append("        .byte " + ",".join("$%02X" % v for v in tranche))
    return "\n".join(lignes) + "\n"


def generer():
    morceaux = [
        "; =====================================================================",
        ";  donnees_tables.asm - tables precalculees",
        ";  FICHIER GENERE PAR outils/generer_tables.py - NE PAS EDITER A LA MAIN",
        "; =====================================================================",
        "",
    ]

    # Debut de chaque ligne de l'ecran, pour pos_ecran.
    debuts = [ECRAN + LARGEUR * y for y in range(25)]
    morceaux.append(octets("lignes_lo", [a & 0xFF for a in debuts],
                           "adresse du premier caractere de la ligne (poids faible)"))
    morceaux.append(octets("lignes_hi", [a >> 8 for a in debuts],
                           "adresse du premier caractere de la ligne (poids fort)"))

    # Coin haut-gauche de chaque case, indexe par l'index 0x88.
    adrs = [adresse_case(i) for i in range(128)]
    morceaux.append(octets("case_adr_lo", [a & 0xFF for a in adrs],
                           "coin haut-gauche de la case 0x88 (poids faible), 0 hors echiquier"))
    morceaux.append(octets("case_adr_hi", [a >> 8 for a in adrs],
                           "coin haut-gauche de la case 0x88 (poids fort), 0 hors echiquier"))

    # Fond de la case : clair si (rangee + colonne) est pair, a8 etant claire.
    # a8 = index $70 : f = 0, g = 7, somme impaire. La maquette veut a8 claire,
    # donc une case est claire quand (f + g) est IMPAIR dans la numerotation
    # 0x88, ce qui correspond bien a (r + c) pair a l'ecran puisque r = 7 - g.
    fonds = []
    for i in range(128):
        if i & 0x88:
            fonds.append(0)
        else:
            f = i & 7
            g = i >> 4
            fonds.append(1 if (f + g) % 2 else 0)
    morceaux.append(octets("case_claire", fonds,
                           "1 si la case 0x88 est une case claire (damier)"))

    return "\n".join(morceaux)


if __name__ == "__main__":
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    chemin = os.path.join(racine, "donnees_tables.asm")
    open(chemin, "w").write(generer())
    print("ecrit " + chemin)
