#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Produit donnees_eval.asm : valeurs des pieces et tables de position.

Les tables sont ecrites en index 0x88 (128 octets, dont 64 utiles) pour
que la recherche y accede sans conversion : table,x ou x est deja l'index
de la case. Elles sont donnees du point de vue des Blancs ; pour les
Noirs, la recherche lit la meme table a l'index case EOR $70, qui
retourne l'echiquier.

Usage :  python3 outils/generer_eval.py
"""

import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Valeurs en centipions, comme CLAUDE.md les fixe.
VALEURS = {"PION": 100, "CAVALIER": 320, "FOU": 330,
           "TOUR": 500, "DAME": 900, "ROI": 0}

# Les tables se lisent comme l'echiquier vu des Blancs : premiere ligne
# du texte = rangee 8, derniere = rangee 1.
TABLES = {
    "PION": """
         0   0   0   0   0   0   0   0
        50  50  50  50  50  50  50  50
        10  10  20  30  30  20  10  10
         5   5  10  25  25  10   5   5
         0   0   0  20  20   0   0   0
         5  -5 -10   0   0 -10  -5   5
         5  10  10 -20 -20  10  10   5
         0   0   0   0   0   0   0   0
    """,
    "CAVALIER": """
       -50 -40 -30 -30 -30 -30 -40 -50
       -40 -20   0   0   0   0 -20 -40
       -30   0  10  15  15  10   0 -30
       -30   5  15  20  20  15   5 -30
       -30   0  15  20  20  15   0 -30
       -30   5  10  15  15  10   5 -30
       -40 -20   0   5   5   0 -20 -40
       -50 -40 -30 -30 -30 -30 -40 -50
    """,
    "FOU": """
       -20 -10 -10 -10 -10 -10 -10 -20
       -10   0   0   0   0   0   0 -10
       -10   0   5  10  10   5   0 -10
       -10   5   5  10  10   5   5 -10
       -10   0  10  10  10  10   0 -10
       -10  10  10  10  10  10  10 -10
       -10   5   0   0   0   0   5 -10
       -20 -10 -10 -10 -10 -10 -10 -20
    """,
    "TOUR": """
         0   0   0   0   0   0   0   0
         5  10  10  10  10  10  10   5
        -5   0   0   0   0   0   0  -5
        -5   0   0   0   0   0   0  -5
        -5   0   0   0   0   0   0  -5
        -5   0   0   0   0   0   0  -5
        -5   0   0   0   0   0   0  -5
         0   0   0   5   5   0   0   0
    """,
    "DAME": """
       -20 -10 -10  -5  -5 -10 -10 -20
       -10   0   0   0   0   0   0 -10
       -10   0   5   5   5   5   0 -10
        -5   0   5   5   5   5   0  -5
         0   0   5   5   5   5   0  -5
       -10   5   5   5   5   5   0 -10
       -10   0   5   0   0   0   0 -10
       -20 -10 -10  -5  -5 -10 -10 -20
    """,
    "ROI": """
       -30 -40 -40 -50 -50 -40 -40 -30
       -30 -40 -40 -50 -50 -40 -40 -30
       -30 -40 -40 -50 -50 -40 -40 -30
       -30 -40 -40 -50 -50 -40 -40 -30
       -20 -30 -30 -40 -40 -30 -30 -20
       -10 -20 -20 -20 -20 -20 -20 -10
        20  20   0   0   0   0  20  20
        20  30  10   0   0  10  30  20
    """,
    "ROI_FINALE": """
       -50 -40 -30 -20 -20 -30 -40 -50
       -30 -20 -10   0   0 -10 -20 -30
       -30 -10  20  30  30  20 -10 -30
       -30 -10  30  40  40  30 -10 -30
       -30 -10  30  40  40  30 -10 -30
       -30 -10  20  30  30  20 -10 -30
       -30 -30   0   0   0   0 -30 -30
       -50 -30 -30 -30 -30 -30 -30 -50
    """,
}


def lire_table(texte):
    """Les 64 valeurs, rangee 1 d'abord : l'ordre du plateau 0x88."""
    rangees = [l.split() for l in texte.strip().splitlines()]
    assert len(rangees) == 8 and all(len(r) == 8 for r in rangees), texte
    valeurs = []
    for r in reversed(rangees):          # la rangee 1 est la derniere ligne
        valeurs.extend(int(v) for v in r)
    return valeurs


def octet_signe(v):
    assert -128 <= v <= 127, v
    return v & 0xFF


def main():
    lignes = [
        "; =====================================================================",
        ";  donnees_eval.asm - valeurs des pieces et tables de position",
        ";",
        ";  FICHIER GENERE par outils/generer_eval.py : ne pas editer a la main.",
        ";  Les tables sont en index 0x88 : les huit octets de bourrage de",
        ";  chaque rangee ne servent pas, mais evitent toute conversion dans la",
        ";  boucle d'evaluation. Elles valent pour les Blancs ; les Noirs lisent",
        ";  la meme table a l'index case EOR $70.",
        "; =====================================================================",
        "",
        "; --- valeur des pieces, en centipions -------------------------------",
    ]
    ordre = ["PION", "CAVALIER", "FOU", "TOUR", "DAME", "ROI"]
    lignes.append("valeurs_lo")
    lignes.append("        .byte 0, " + ", ".join(
        "<%d" % VALEURS[n] for n in ordre))
    lignes.append("valeurs_hi")
    lignes.append("        .byte 0, " + ", ".join(
        ">%d" % VALEURS[n] for n in ordre))
    lignes.append("")
    lignes.append("; Valeur approchee pour le tri des prises (MVV-LVA), en")
    lignes.append("; pions : elle tient alors sur quatre bits. Le roi vaut plus")
    lignes.append("; que la dame : c'est le plus mauvais des preneurs.")
    tri = dict((n, min(15, int(round(VALEURS[n] / 100.0)))) for n in ordre)
    tri["ROI"] = 10
    lignes.append("valeurs_tri")
    lignes.append("        .byte 0, " + ", ".join(
        "%d" % tri[n] for n in ordre))
    lignes.append("")

    noms_asm = {"PION": "eval_pion", "CAVALIER": "eval_cavalier",
                "FOU": "eval_fou", "TOUR": "eval_tour", "DAME": "eval_dame",
                "ROI": "eval_roi", "ROI_FINALE": "eval_roi_finale"}
    adresses = []
    for nom in ordre + ["ROI_FINALE"]:
        valeurs = lire_table(TABLES[nom])
        lignes.append("%s" % noms_asm[nom])
        for r in range(8):
            rangee = valeurs[r * 8:(r + 1) * 8]
            lignes.append("        .char " + ", ".join(
                "%3d" % v for v in rangee) + "    ; rangee %d" % (r + 1))
            lignes.append("        .char 0, 0, 0, 0, 0, 0, 0, 0")
        lignes.append("")
        adresses.append(noms_asm[nom])

    lignes.append("; Adresse de la table de chaque type de piece, indexee par")
    lignes.append("; le type (1 a 6) ; l'entree 0 ne sert pas.")
    lignes.append("eval_tables_lo")
    lignes.append("        .byte 0, " + ", ".join(
        "<%s" % noms_asm[n] for n in ordre))
    lignes.append("eval_tables_hi")
    lignes.append("        .byte 0, " + ", ".join(
        ">%s" % noms_asm[n] for n in ordre))
    lignes.append("")

    chemin = os.path.join(RACINE, "donnees_eval.asm")
    with open(chemin, "w") as f:
        f.write("\n".join(lignes) + "\n")
    print("ecrit %s" % chemin)
    return 0


if __name__ == "__main__":
    sys.exit(main())
