#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifie les codes ecran des 16 quarts de bloc dans un generateur de caracteres.

Les pieces du jeu sont dessinees avec les quarts de bloc PETSCII ; leurs
codes ne sont pas les memes d'une ROM de caracteres a l'autre. Ce script
lit un generateur de caracteres, reconnait les glyphes qui sont des quarts
de bloc et dit quel code donne quel masque, en video normale comme en
video inverse. Il sert a valider la table QUARTS de generer_pieces.py, et
a repondre a la question ouverte de la ROM EDEX.

Les ROM Commodore ne font pas partie du depot : il faut les fournir.

Usage :
    python3 outils/verifier_quarts.py ~/.local/share/vice/PET/characters-2.901447-10.bin
"""

import sys

NOMS = {
    0: "vide", 1: "haut-gauche", 2: "haut-droit", 3: "demi-haut",
    4: "bas-gauche", 5: "demi-gauche", 6: "diagonale /", 7: "sauf bas-droit",
    8: "bas-droit", 9: "diagonale \\", 10: "demi-droit", 11: "sauf bas-gauche",
    12: "demi-bas", 13: "sauf haut-droit", 14: "sauf haut-gauche", 15: "plein",
}


def masque(glyphe):
    """Masque de quarts du glyphe, ou None si ce n'est pas un quart de bloc.

    Chaque quart couvre 4 x 4 pixels. On exige qu'il soit franchement plein
    (au moins 14 pixels sur 16) ou franchement vide (au plus 2), sans quoi
    le glyphe est autre chose : une lettre, un trait, un arc.
    """
    m = 0
    bits = {(0, 0): 1, (1, 0): 2, (0, 1): 4, (1, 1): 8}
    for (qx, qy), bit in bits.items():
        n = 0
        for y in range(qy * 4, qy * 4 + 4):
            for x in range(qx * 4, qx * 4 + 4):
                if glyphe[y] & (0x80 >> x):
                    n += 1
        if n >= 14:
            m |= bit
        elif n > 2:
            return None
    return m


def main(chemin):
    octets = open(chemin, "rb").read()
    nb_jeux = len(octets) // 1024
    print("%s : %d glyphes, %d jeu(x) de 128" % (chemin, len(octets) // 8, nb_jeux))
    for jeu in range(nb_jeux):
        print("=== jeu %d (mode %s) ===" % (jeu, "#12 graphique" if jeu == 0 else "#14 texte"))
        trouve = {}
        for code in range(128):
            g = octets[(jeu * 128 + code) * 8:(jeu * 128 + code) * 8 + 8]
            m = masque(g)
            if m is not None:
                trouve.setdefault(m, []).append(code)
            m = masque(bytes(255 - b for b in g))
            if m is not None:
                trouve.setdefault(m, []).append(code + 128)
        manquants = []
        for m in range(16):
            codes = trouve.get(m)
            if codes is None:
                manquants.append(m)
                print("  masque %2d %-16s ABSENT" % (m, NOMS[m]))
            else:
                print("  masque %2d %-16s code %d%s" % (
                    m, NOMS[m], codes[0],
                    "" if len(codes) == 1 else "  (aussi %s)" % codes[1:]))
        if manquants:
            print("  -> jeu inutilisable pour les pieces : masques manquants %s" % manquants)
        else:
            print("  -> les 16 quarts sont disponibles")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
