#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere donnees_pieces.asm : les 12 codes ecran de chaque piece.

Chaque piece est dessinee sur une grille de 8 x 6 "pixels". Un caractere
du 8296 couvre 2 x 2 pixels grace aux quarts de bloc PETSCII : une piece
occupe donc 4 x 3 caracteres.

Masque d'un caractere (cx = 0..3, cy = 0..2) :
    pixel (2cx,   2cy)   -> bit 1   (quart haut-gauche)
    pixel (2cx+1, 2cy)   -> bit 2   (quart haut-droit)
    pixel (2cx,   2cy+1) -> bit 4   (quart bas-gauche)
    pixel (2cx+1, 2cy+1) -> bit 8   (quart bas-droit)

Une piece blanche est une silhouette lumineuse sur fond sombre ; une piece
noire est la meme silhouette sombre dans un rectangle allume, soit le
masque inverse (masque XOR 15). Comme la video inverse d'un quart de bloc
est exactement le quart complementaire, cette inversion est aussi celle du
curseur : inverser toute la case revient a echanger les deux tables.
"""

import os

# ---------------------------------------------------------------------
#  Codes ecran des 16 combinaisons de quarts, ROM standard, mode #12.
#  Verifies en lisant le generateur de caracteres de VICE
#  (characters-2.901447-10.bin) : voir outils/verifier_quarts.py.
# ---------------------------------------------------------------------
QUARTS = {
    0:  32,     # vide
    1:  126,    # haut-gauche
    2:  124,    # haut-droit
    3:  226,    # demi-haut        (inverse de 98)
    4:  123,    # bas-gauche
    5:  97,     # demi-gauche
    6:  255,    # diagonale        (inverse de 127)
    7:  236,    # tout sauf bas-droit (inverse de 108)
    8:  108,    # bas-droit
    9:  127,    # diagonale
    10: 225,    # demi-droit       (inverse de 97)
    11: 251,    # tout sauf bas-gauche (inverse de 123)
    12: 98,     # demi-bas
    13: 252,    # tout sauf haut-droit (inverse de 124)
    14: 254,    # tout sauf haut-gauche (inverse de 126)
    15: 160,    # plein            (espace inverse)
}

# ---------------------------------------------------------------------
#  Dessins des six pieces (disposition validee sur maquette)
#  L'ordre suit l'encodage interne : PION, CAVALIER, FOU, TOUR, DAME, ROI.
# ---------------------------------------------------------------------
PIECES = [
    ("PION", [
        "........",
        "...##...",
        "..####..",
        "...##...",
        "..####..",
        ".######.",
    ]),
    ("CAVALIER", [
        "...#.#..",
        "..#####.",
        ".######.",
        "##..###.",
        "...####.",
        ".######.",
    ]),
    ("FOU", [
        "...##...",
        "..##.#..",
        "..####..",
        "...##...",
        "..####..",
        ".######.",
    ]),
    ("TOUR", [
        "##.##.##",
        "########",
        ".######.",
        "..####..",
        "..####..",
        ".######.",
    ]),
    ("DAME", [
        "#..##..#",
        "##.##.##",
        ".######.",
        "..####..",
        "..####..",
        ".######.",
    ]),
    ("ROI", [
        "...##...",
        ".######.",
        "...##...",
        "..####..",
        "..####..",
        ".######.",
    ]),
]


# ---------------------------------------------------------------------
#  Pieces de la version EDEX
#
#  L'EPROM francaise n'a pas les quarts de bloc : ses codes 97 a 127 sont
#  des cadres et des accents. Les pieces y sont donc dessinees avec les
#  formes dont elle dispose -- quatre triangles d'angle et le bloc plein --
#  relevees sur la vraie 8296 :
#
#      81 = coin haut-gauche    65 = coin haut-droit
#     209 = coin bas-droit     193 = coin bas-gauche
#     160 = bloc plein          32 = vide
#
#  Ce sont des codes ecran directs, pas des masques de quarts : on ne peut
#  pas les calculer depuis un dessin en pixels. Ils sont donc donnes tels
#  quels, douze par piece, lus de gauche a droite puis de haut en bas,
#  comme la table des quarts.
#
#  Une piece noire est le meme dessin en video inverse (code XOR 128), ce
#  qui donne la silhouette sombre dans un rectangle allume -- et, comme
#  pour les quarts, inverser toute la case revient a echanger les tables.
# ---------------------------------------------------------------------
PIECES_EDEX = {
    "PION": [32, 32, 32, 32,
             32, 209, 193, 32,
             209, 160, 160, 193],
    "CAVALIER": [32, 209, 160, 193,
                 160, 81, 160, 32,
                 209, 160, 160, 193],
    "FOU": [32, 209, 193, 32,
            32, 65, 81, 32,
            209, 160, 160, 193],
    "TOUR": [160, 88, 88, 160,
             65, 160, 160, 81,
             209, 160, 160, 193],
    "DAME": [209, 193, 209, 193,
             65, 160, 160, 81,
             209, 160, 160, 193],
    "ROI": [32, 103, 101, 32,
            32, 160, 160, 32,
            209, 160, 160, 193],
}


def masques(dessin):
    """Les 12 masques d'une piece, dans l'ordre de lecture (cy puis cx)."""
    assert len(dessin) == 6, "une piece fait 6 lignes de pixels"
    for ligne in dessin:
        assert len(ligne) == 8, "une piece fait 8 pixels de large : " + ligne
    res = []
    for cy in range(3):
        for cx in range(4):
            m = 0
            if dessin[2 * cy][2 * cx] == "#":
                m |= 1
            if dessin[2 * cy][2 * cx + 1] == "#":
                m |= 2
            if dessin[2 * cy + 1][2 * cx] == "#":
                m |= 4
            if dessin[2 * cy + 1][2 * cx + 1] == "#":
                m |= 8
            res.append(m)
    return res


def apercu(dessin):
    """Rend le dessin en commentaire, pour pouvoir relire l'assembleur."""
    return ["; " + ligne for ligne in dessin]


def generer():
    lignes = [
        "; =====================================================================",
        ";  donnees_pieces.asm - les 12 codes ecran de chacune des six pieces",
        ";  FICHIER GENERE PAR outils/generer_pieces.py - NE PAS EDITER A LA MAIN",
        ";",
        ";  Table indexee par (type - 1) * 12, les 12 caracteres se lisant de",
        ";  gauche a droite puis de haut en bas (4 colonnes x 3 lignes).",
        "; =====================================================================",
        "",
    ]
    for nom, table in (("pieces_blanches", False), ("pieces_noires", True)):
        lignes.append("; ---------------------------------------------------------------------")
        if table:
            lignes.append(";  Pieces noires : silhouette sombre dans un rectangle allume")
        else:
            lignes.append(";  Pieces blanches : silhouette lumineuse sur fond sombre")
        lignes.append("; ---------------------------------------------------------------------")
        lignes.append(nom + ":")
        for piece, dessin in PIECES:
            lignes.append("        ; --- " + piece + " ---")
            lignes += ["        " + l for l in apercu(dessin)]
            ms = masques(dessin)
            if table:
                ms = [m ^ 15 for m in ms]
            for cy in range(3):
                tranche = ms[cy * 4:cy * 4 + 4]
                lignes.append("        .byte " + ",".join("%3d" % QUARTS[m] for m in tranche))
        lignes.append("")

    # --- les memes pieces, version EDEX ---
    for nom, inverse in (("pieces_edex_blanches", False),
                         ("pieces_edex_noires", True)):
        lignes.append("; ---------------------------------------------------------------------")
        if inverse:
            lignes.append(";  Pieces EDEX noires : le meme dessin en video inverse")
        else:
            lignes.append(";  Pieces EDEX blanches : triangles d'angle et blocs pleins, les")
            lignes.append(";  seules formes que l'EPROM francaise offre en mode graphique")
        lignes.append("; ---------------------------------------------------------------------")
        lignes.append(nom + ":")
        for piece, _ in PIECES:
            codes = PIECES_EDEX[piece]
            assert len(codes) == 12, piece
            lignes.append("        ; --- " + piece + " ---")
            for cy in range(3):
                tranche = codes[cy * 4:cy * 4 + 4]
                if inverse:
                    tranche = [c ^ 128 for c in tranche]
                lignes.append("        .byte "
                              + ",".join("%3d" % c for c in tranche))
        lignes.append("")
    return "\n".join(lignes) + "\n"


if __name__ == "__main__":
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    chemin = os.path.join(racine, "donnees_pieces.asm")
    open(chemin, "w").write(generer())
    print("ecrit " + chemin)
