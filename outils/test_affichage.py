#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests automatiques de l'affichage et de la saisie (etape 1).

Chaque scenario lance le jeu dans VICE en injectant une suite de touches,
relit l'ecran produit avec outils/lire_ecran.py, et verifie que les lignes
attendues contiennent bien le texte voulu.

Usage :  python3 outils/test_affichage.py [-v] [motif]

Limite connue : l'option -keybuf de VICE ne transmet que des caracteres deja
decodes. Elle ne passe donc ni les fleches du curseur ($1D/$9D/$11/$91) ni la
touche DEL ($14), et les lettres doivent y etre ecrites en minuscules. Les
scenarios ci-dessous deplacent le curseur avec le pave numerique, qui emet des
chiffres ordinaires ; les fleches et DEL restent a verifier a la main, puis
sur la vraie machine.
"""

import os
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from lire_ecran import lire_grille, symbole          # noqa: E402

PRG = os.path.join(RACINE, "echecs.prg")
CYCLES = "30000000"

# Quelques scenarios demandent plus de temps machine que les autres :
# celui ou l'ordinateur reflechit, par exemple. Le plafond du niveau 1
# est d'une seconde, mais l'autostart de VICE en a deja consomme une
# bonne part.
CYCLES_SPECIAUX = {
    "l'ordinateur repond au premier coup": "60000000",
}

# Le curseur part de E2. Rappel du pave : 8 monte, 2 descend, 4 et 6 vont
# a gauche et a droite, 7 9 1 3 sont les diagonales.
#
# Un scenario : (nom, touches, [(ligne, texte attendu), ...])
SCENARIOS = [
    ("ecran de choix de la ROM", "", [
        (0, "JEU D'ECHECS"),
        (3, "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"),
        (7, "1 - STANDARD"),
        (7, "2 - EDEX"),
        (7, "3 - LETTRES"),
        (22, "1, 2 OU 3 POUR CHOISIR      RETURN POUR VALIDER"),
    ]),
    ("position de depart", "\n", [
        (0, "JEU D'ECHECS"),
        (0, "CBM 8296"),
        (2, "TRAIT  : BLANCS"),
        (3, "ORDI   : AUCUN"),
        (4, "NIVEAU : 3 MOYEN"),
        (5, "PENDULE:"),
        (7, "PARTIE"),
        (10, "PIECES PRISES"),
        (13, "LEGENDE"),
        (14, "R ROI  D DAME  T TOUR"),
        (15, "F FOU  C CAVALIER"),
        (16, "P PION"),
        (17, "LUMINEUX = BLANCS"),
        (18, "SOMBRE = NOIRS"),
        (20, "NOUVELLE PARTIE"),
        (21, "AUX BLANCS DE JOUER"),
        (22, "VOTRE COUP :"),
        (23, "CURSEUR : E2"),
        (24, "U=ANNUL ?=AIDE N=NOUV Q=FIN"),
    ]),
    ("coordonnees de l'echiquier", "\n", [
        (1, "8"),
        (22, "1"),
        (24, "A     B     C     D     E     F     G     H"),
    ]),
    # --- deplacement du curseur --------------------------------------
    ("pave 8 : une case vers le haut", "\n8", [(23, "CURSEUR : E3")]),
    ("pave 2 : une case vers le bas", "\n2", [(23, "CURSEUR : E1")]),
    ("pave 4 : une case a gauche", "\n4", [(23, "CURSEUR : D2")]),
    ("pave 6 : une case a droite", "\n6", [(23, "CURSEUR : F2")]),
    ("pave 7 : diagonale haut-gauche", "\n7", [(23, "CURSEUR : D3")]),
    ("pave 9 : diagonale haut-droite", "\n9", [(23, "CURSEUR : F3")]),
    ("pave 1 : diagonale bas-gauche", "\n1", [(23, "CURSEUR : D1")]),
    ("pave 3 : diagonale bas-droite", "\n3", [(23, "CURSEUR : F1")]),
    ("le curseur ne sort pas par le bas", "\n22", [(23, "CURSEUR : E1")]),
    ("le curseur ne sort pas par la gauche", "\n44444", [(23, "CURSEUR : A2")]),
    ("le curseur ne sort pas par le haut", "\n8888888888", [(23, "CURSEUR : E8")]),
    # --- selection ----------------------------------------------------
    ("selection d'un pion", "\n ", [
        (20, "PION E2 SELECTIONNE"),
        (21, "DESTINATION ?"),
        (22, "VOTRE COUP : E2-"),
    ]),
    ("selection d'un cavalier", "\n266 ", [
        (20, "CAVALIER G1 SELECTIONNE"),
        (22, "VOTRE COUP : CG1-"),
    ]),
    ("revalider relache la piece", "\n  ", [
        (20, "CHOISISSEZ UNE PIECE"),
        (21, "AUX BLANCS DE JOUER"),
    ]),
    ("changement de piece choisie", "\n 6 ", [
        (20, "PION F2 SELECTIONNE"),
    ]),
    ("case vide sans piece choisie", "\n88 ", [
        (20, "CASE VIDE"),
        (21, "CHOISISSEZ UNE DE VOS PIECES"),
    ]),
    ("piece de l'adversaire", "\n888888 ", [
        (20, "CETTE PIECE EST A"),
        (21, "L'ADVERSAIRE"),
    ]),
    # Au curseur, viser une de ses propres pieces change simplement de
    # selection : seule la saisie en notation peut demander l'impossible.
    ("arrivee sur une piece amie refusee", "\ne2-d1\n", [
        (20, "COUP IMPOSSIBLE"),
    ]),
    # --- coups joues au curseur ---------------------------------------
    ("coup joue au curseur", "\n 88 ", [
        (2, "TRAIT  : NOIRS"),
        (8, "E2-E4"),
        (21, "AUX NOIRS DE JOUER"),
        (23, "CURSEUR : E4"),       # le curseur suit la piece jouee
    ]),
    ("deux coups : la liste se remplit", "\n 88 888 22 ", [
        (2, "TRAIT  : BLANCS"),
        (8, "E2-E4  E7-E5"),
    ]),
    # 1. E2-E4  2. D7-D5  3. E4xD5 : le pion noir passe dans les prises
    ("prise : la piece est comptee", "\n 88 8884 22 3 7 ", [
        (8, "E2-E4  D7-D5  E4XD5"),
        (11, "P"),
        (2, "TRAIT  : NOIRS"),
    ]),
    # --- retour en arriere --------------------------------------------
    ("retour en arriere", "\n 88 u", [
        (2, "TRAIT  : BLANCS"),
        (8, ""),                    # la liste des coups est revenue a vide
        (20, "COUP ANNULE"),
        (23, "CURSEUR : E2"),
    ]),
    ("retour en arriere sans rien a defaire", "\nu", [
        (20, "AUCUN COUP A ANNULER"),
    ]),
    # --- saisie en notation -------------------------------------------
    ("une lettre ouvre la saisie", "\ne", [
        (22, "VOTRE COUP : E"),
    ]),
    ("saisie d'un coup complet", "\ne2-e4\n", [
        (2, "TRAIT  : NOIRS"),
        (8, "E2-E4"),
    ]),
    ("saisie avec l'initiale de la piece", "\ncg1-f3\n", [
        (2, "TRAIT  : NOIRS"),
        (8, "CG1-F3"),
    ]),
    ("saisie d'une case seule : la piece est choisie", "\nd2\n", [
        (20, "PION D2 SELECTIONNE"),
        (23, "CURSEUR : D2"),
    ]),
    ("saisie incomprehensible", "\ne9-e4\n", [
        (20, "SAISIE INVALIDE"),
    ]),
    ("saisie d'une piece adverse", "\ne7-e5\n", [
        (20, "CETTE PIECE EST A"),
    ]),
    # --- regles (etape 2) ---------------------------------------------
    ("le roque est refuse tant qu'il est bouche", "\no-o\n", [
        (20, "ROQUE IMPOSSIBLE"),
    ]),
    # 1.e4 e5 2.Cf3 Cc6 3.Fc4 Fc5 4.O-O : le petit roque devient jouable
    ("petit roque joue", "\ne2-e4\ne7-e5\ng1-f3\nb8-c6\nf1-c4\nf8-c5\no-o\n", [
        (8, "E2-E4"),
        (9, "O-O"),
        (2, "TRAIT  : NOIRS"),
    ]),
    ("coup illegal refuse", "\ne2-e5\n", [
        (20, "COUP IMPOSSIBLE"),
    ]),
    ("piece sans coup legal", "\na1\n", [
        (20, "AUCUN COUP POUR CETTE PIECE"),
    ]),
    # 1.e4 e5 2.Dh5 Cc6 3.Fc4 Cf6?? 4.Dxf7#
    ("mat du berger", "\ne2-e4\ne7-e5\nd1-h5\nb8-c6\nf1-c4\ng8-f6\nh5xf7\n", [
        (20, "ECHEC ET MAT"),
        (21, "BLANCS GAGNENT"),
    ]),
    # 1.e4 e5 2.Dh5 Cf6 : la dame donne echec sans mater
    ("echec annonce", "\ne2-e4\nf7-f5\nd1-h5\n", [
        (20, "ECHEC AU ROI"),
        (21, "AUX NOIRS DE JOUER"),
    ]),
    # 1.e4 d5 2.e5 f5 3.exf6 e.p.
    ("prise en passant", "\ne2-e4\nd7-d5\ne4-e5\nf7-f5\ne5xf6\n", [
        (9, "E5XF6"),
        (11, "P"),
    ]),
    # 1.g4 a5 2.g5 a4 3.g6 a3 4.gxh7 axb2 5.hxg8 : le pion promeut en
    # prenant le cavalier
    ("la promotion demande la piece",
     "\ng2-g4\na7-a5\ng4-g5\na5-a4\ng5-g6\na4-a3\ng6xh7\na3xb2\nh7xg8\n", [
        (20, "PROMOTION : D T F C"),
        (21, "RETURN POUR LA DAME"),
    ]),
    ("promotion en tour",
     "\ng2-g4\na7-a5\ng4-g5\na5-a4\ng5-g6\na4-a3\ng6xh7\na3xb2\nh7xg8\nt", [
        (9, "TH7XG8"),
        (2, "TRAIT  : NOIRS"),
    ]),
    # Les cavaliers vont et viennent : la position de depart revient une
    # troisieme fois apres huit demi-coups.
    ("triple repetition",
     "\ng1-f3\ng8-f6\nf3-g1\nf6-g8\ng1-f3\ng8-f6\nf3-g1\nf6-g8\n", [
        (20, "NULLE : TRIPLE REPETITION"),
        (21, "PARTIE FINIE"),
    ]),
    # --- l'adversaire (etape 3) ---------------------------------------
    ("l'ordinateur prend un camp", "\nj", [
        (3, "ORDI   : NOIRS"),
    ]),
    ("l'ordinateur rend les deux camps", "\njjj", [
        (3, "ORDI   : AUCUN"),
    ]),
    ("l'ordinateur repond au premier coup", "\nl1je2-e4\n", [
        (2, "TRAIT  : BLANCS"),
        (3, "ORDI   : NOIRS"),
        (8, "E2-E4"),
    ]),
    ("annulation d'un coup", "\ne2-e4\nu", [
        (20, "COUP ANNULE"),
        (2, "TRAIT  : BLANCS"),
    ]),
    # --- commandes ----------------------------------------------------
    ("ecran d'aide", "\n?", [
        (0, "AIDE - LES TOUCHES DU JEU"),
        (4, "FLECHES / PAVE 8 2 4 6   DEPLACER LE CURSEUR"),
        (12, "ANNULER LE DERNIER COUP"),
        (22, "UNE TOUCHE POUR REVENIR A LA PARTIE"),
    ]),
    ("l'aide rend l'echiquier", "\n? ", [
        (2, "TRAIT  : BLANCS"),
        (23, "CURSEUR : E2"),
    ]),
    ("changement de niveau", "\nl6", [
        (4, "NIVEAU : 6 MAXIMUM"),
    ]),
    ("nouvelle partie demande confirmation", "\n 88 n", [
        (20, "NOUVELLE PARTIE ?"),
        (21, "O = OUI, AUTRE = NON"),
    ]),
    ("nouvelle partie confirmee", "\n 88 no", [
        (2, "TRAIT  : BLANCS"),
        (8, ""),
        (20, "NOUVELLE PARTIE"),
        (23, "CURSEUR : E2"),
    ]),
    ("nouvelle partie refusee", "\n 88 nx", [
        (2, "TRAIT  : NOIRS"),
        (8, "E2-E4"),
    ]),
    ("M ramene au choix de la ROM", "\nm", [
        (3, "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"),
    ]),
    # Q rend la main au BASIC : on verifie qu'une commande tapee ensuite
    # s'execute normalement, donc que la machine est dans un etat sain.
    ("retour au BASIC par Q", "\nqoprint\"retour ok\"\n", [
        (None, "RETOUR OK"),
        (None, "READY."),
    ]),
    # --- les deux autres jeux de caracteres ---------------------------
    ("ROM EDEX : la partie se joue normalement", "2\ne2-e4\n", [
        (2, "TRAIT  : NOIRS"),
        (8, "E2-E4"),
        (23, "CURSEUR : E4"),
    ]),
    ("repli lettres : la partie se joue normalement", "3\ne2-e4\n", [
        (2, "TRAIT  : NOIRS"),
        (8, "E2-E4"),
        (23, "CURSEUR : E4"),
    ]),
    ("retour au menu depuis EDEX", "2\nm", [
        (3, "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"),
        (7, "2 - EDEX"),
    ]),
]


def jouer(touches, image, cycles=CYCLES):
    cmd = ["xpet", "-model", "8296", "-autostart", PRG,
           "-limitcycles", cycles, "-exitscreenshot", image, "-warp", "+sound"]
    if touches:
        cmd += ["-keybuf", touches]
    subprocess.run(cmd, capture_output=True, timeout=300)


def texte_ligne(grille, n):
    """Ligne d'ecran en texte. La video inverse est ignoree pour la
    comparaison, et un espace inverse (fond des cases foncees, bandeaux)
    redevient un espace."""
    return "".join(symbole(c).replace("#", " ") for c in grille[n]).rstrip()


# E2 est la case de depart du curseur : index 0x88 $14, donc ligne 18 et
# colonne 26 de l'ecran. C'est une case claire, dont le fond est le damier.
E2_LIGNE, E2_COL = 18, 26
DAMIER = 102
PLEIN = 160                             # espace inverse : le bloc plein
VIDE = 32
PION_B_HAUT = [32, 108, 123, 32]        # premiere ligne du pion blanc
PION_N_HAUT = [160, 236, 251, 160]      # la meme, quarts inverses


def test_curseur(dossier):
    """Le curseur fait battre toute la case en inversion video.

    Le complement d'un quart de bloc est exactement son inverse video :
    inverser la case revient donc a echanger les tables des Blancs et des
    Noirs, et la piece bat avec son fond, d'un seul tenant.

    Le fond, lui, ne prend pas l'inverse du damier, qui lui ressemble trop :
    sous le curseur il passe au bloc plein. E2 est une case claire, c'est
    donc bien ce cas-la qu'on juge ici.
    """
    fonds, pieces = set(), set()
    for cycles in range(28000000, 29200001, 150000):
        image = os.path.join(dossier, "clign.png")
        if os.path.exists(image):
            os.remove(image)
        cmd = ["xpet", "-model", "8296", "-autostart", PRG,
               "-limitcycles", str(cycles), "-exitscreenshot", image,
               "-warp", "+sound", "-keybuf", "\n"]
        subprocess.run(cmd, capture_output=True, timeout=300)
        if not os.path.exists(image):
            continue
        grille, infos = lire_grille(image)
        if infos[5] != 2000:        # capture prise en plein rafraichissement
            continue
        fonds.add(grille[E2_LIGNE][E2_COL])
        pieces.add(tuple(grille[E2_LIGNE][E2_COL + 1:E2_COL + 5]))
    if not {DAMIER, PLEIN} <= fonds:
        return ("le fond de la case sous le curseur ne bat pas (vu : %s)"
                % " ".join("$%02X" % e for e in sorted(fonds)))
    attendu = {tuple(PION_B_HAUT), tuple(PION_N_HAUT)}
    if not attendu <= pieces:
        return ("la piece sous le curseur ne suit pas l'inversion (vu : %s)"
                % pieces)
    return None


def test_selection(dossier):
    """La piece choisie garde deux barres tranchantes sur ses bords.

    On choisit le pion de E2 puis on eloigne le curseur, pour juger le
    marquage seul : les colonnes 0 et 5 de la case prennent le caractere
    qui tranche sur le fond (le bloc plein sur une case claire au repos),
    les quatre colonnes de la piece restent intactes.
    """
    image = os.path.join(dossier, "select.png")
    if os.path.exists(image):
        os.remove(image)
    cmd = ["xpet", "-model", "8296", "-autostart", PRG,
           "-limitcycles", CYCLES, "-exitscreenshot", image,
           "-warp", "+sound", "-keybuf", "\n 8"]
    subprocess.run(cmd, capture_output=True, timeout=300)
    if not os.path.exists(image):
        return "pas de capture d'ecran"
    grille, _ = lire_grille(image)
    problemes = []
    for dl in range(3):
        ligne = grille[E2_LIGNE + dl]
        if ligne[E2_COL] != PLEIN or ligne[E2_COL + 5] != PLEIN:
            problemes.append("ligne %d : bords $%02X et $%02X au lieu de $%02X"
                             % (E2_LIGNE + dl, ligne[E2_COL],
                                ligne[E2_COL + 5], PLEIN))
    if list(grille[E2_LIGNE][E2_COL + 1:E2_COL + 5]) != PION_B_HAUT:
        problemes.append("la piece choisie a change d'aspect : %s"
                         % grille[E2_LIGNE][E2_COL + 1:E2_COL + 5])
    return "; ".join(problemes) if problemes else None


def test_destinations(dossier):
    """Les cases ou la piece choisie peut aller portent un marquage.

    On choisit le cavalier de G1 : il peut aller en F3 et en H3, toutes
    deux vides. Le marquage est un petit bloc au centre de la case, dans
    le caractere qui tranche sur le fond. F3 est une case claire, donc
    son fond est le damier et le bloc est plein.
    """
    image = os.path.join(dossier, "dest.png")
    if os.path.exists(image):
        os.remove(image)
    cmd = ["xpet", "-model", "8296", "-autostart", PRG,
           "-limitcycles", CYCLES, "-exitscreenshot", image,
           "-warp", "+sound", "-keybuf", "\ng1\n"]
    subprocess.run(cmd, capture_output=True, timeout=300)
    if not os.path.exists(image):
        return "pas de capture d'ecran"
    grille, _ = lire_grille(image)
    problemes = []
    # F3 : colonne 5, rangee 3 -> x0 = 32, y0 = 15 ; centre en 16, 34-35
    for colonne in (34, 35):
        if grille[16][colonne] != PLEIN:
            problemes.append("F3 colonne %d : $%02X au lieu de $%02X"
                             % (colonne, grille[16][colonne], PLEIN))
    # une case ou le cavalier ne peut pas aller garde son fond : E3,
    # colonne 4, rangee 3 -> x0 = 26, case foncee
    for colonne in (28, 29):
        if grille[16][colonne] != VIDE:
            problemes.append("E3 colonne %d : $%02X au lieu de $%02X"
                             % (colonne, grille[16][colonne], VIDE))
    return "; ".join(problemes) if problemes else None


# Les douze codes ecran de trois pieces EDEX, releves sur la vraie 8296 :
# quatre triangles d'angle (81 haut-gauche, 65 haut-droit, 209 bas-droit,
# 193 bas-gauche) et le bloc plein. Une piece noire est le meme dessin en
# video inverse, code XOR 128.
EDEX_PION_B = [[32, 32, 32, 32],
               [32, 209, 193, 32],
               [209, 160, 160, 193]]
EDEX_TOUR_B = [[160, 88, 88, 160],
               [65, 160, 160, 81],
               [209, 160, 160, 193]]
EDEX_POINTILLE = 46


def test_pieces_edex(dossier):
    """La version EDEX pose bien les codes releves sur la vraie machine.

    VICE n'a que la ROM standard : on ne peut pas y juger a l'oeil ce que
    ces codes donneront sur la 8296 du proprietaire, puisque les memes
    numeros y designent d'autres glyphes. Ce qui se verifie ici, et qui
    suffit, c'est que le programme ecrit les bons codes aux bons endroits.

    On regarde la colonne A, loin du curseur qui bat : le pion blanc de
    A2, le pion noir de A7 (le meme dessin inverse) et la tour de A1.
    """
    image = os.path.join(dossier, "edex.png")
    if os.path.exists(image):
        os.remove(image)
    cmd = ["xpet", "-model", "8296", "-autostart", PRG,
           "-limitcycles", CYCLES, "-exitscreenshot", image,
           "-warp", "+sound", "-keybuf", "2\n"]
    subprocess.run(cmd, capture_output=True, timeout=300)
    if not os.path.exists(image):
        return "pas de capture d'ecran"
    grille, _ = lire_grille(image)
    problemes = []
    # colonne A : x0 = 2, la piece occupe les colonnes 3 a 6
    for nom, ligne0, attendu, inverse in (
            ("pion blanc A2", 18, EDEX_PION_B, False),
            ("pion noir A7", 3, EDEX_PION_B, True),
            ("tour blanche A1", 21, EDEX_TOUR_B, False)):
        for dl in range(3):
            vu = list(grille[ligne0 + dl][3:7])
            veut = attendu[dl]
            if inverse:
                veut = [c ^ 128 for c in veut]
            if vu != veut:
                problemes.append("%s ligne %d : %s au lieu de %s"
                                 % (nom, dl, vu, veut))
    # cases claires en pointille, cases foncees vides
    if grille[18][2] != EDEX_POINTILLE:
        problemes.append("A2 est une case claire : fond $%02X au lieu de $%02X"
                         % (grille[18][2], EDEX_POINTILLE))
    if grille[21][2] != VIDE:
        problemes.append("A1 est une case foncee : fond $%02X au lieu de $%02X"
                         % (grille[21][2], VIDE))
    return "; ".join(problemes) if problemes else None


def main():
    bavard = "-v" in sys.argv
    motifs = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not os.path.exists(PRG):
        print("echecs.prg absent : lancer d'abord "
              "64tass --cbm-prg -o echecs.prg main.asm")
        return 1
    echecs = 0
    lances = 0
    # Controle sans emulateur : un message trop long pour le panneau
    # deborde sur la ligne suivante, colonne 0, donc par-dessus
    # l'echiquier. Le defaut est discret, autant le voir tout de suite.
    if not motifs or any(m in "largeur des messages" for m in motifs):
        lances += 1
        if subprocess.run([sys.executable,
                           os.path.join(RACINE, "outils",
                                        "verifier_textes.py")]).returncode:
            echecs += 1
    with tempfile.TemporaryDirectory() as dossier:
        for nom, touches, attentes in SCENARIOS:
            if motifs and not any(m in nom for m in motifs):
                continue
            lances += 1
            image = os.path.join(dossier, "ecran.png")
            if os.path.exists(image):
                os.remove(image)
            jouer(touches, image, CYCLES_SPECIAUX.get(nom, CYCLES))
            if not os.path.exists(image):
                print("ECHEC  %-42s : pas de capture d'ecran" % nom)
                echecs += 1
                continue
            grille, _ = lire_grille(image)
            manques = []
            for ligne, attendu in attentes:
                if ligne is None:       # cherche n'importe ou sur l'ecran
                    tout = "\n".join(texte_ligne(grille, i) for i in range(25))
                    if attendu not in tout:
                        manques.append(("*", attendu, tout.replace("\n", " | ")[:70]))
                elif attendu not in texte_ligne(grille, ligne):
                    manques.append((ligne, attendu, texte_ligne(grille, ligne)))
            if manques:
                echecs += 1
                print("ECHEC  %s" % nom)
                for ligne, attendu, obtenu in manques:
                    print("       ligne %-2s attendu : %r" % (ligne, attendu))
                    print("                obtenu  : %r" % obtenu)
            else:
                print("ok     %s" % nom)
            if bavard:
                for i in range(25):
                    print("    %2d| %s" % (i, texte_ligne(grille, i)))
        for nom, essai in (("battement du curseur", test_curseur),
                           ("marquage de la piece choisie", test_selection),
                           ("marquage des destinations", test_destinations),
                           ("pieces EDEX", test_pieces_edex)):
                if motifs and not any(m in nom for m in motifs):
                    continue
                probleme = essai(dossier)
                lances += 1
                if probleme:
                    echecs += 1
                    print("ECHEC  %s : %s" % (nom, probleme))
                else:
                    print("ok     %s" % nom)
    print("%d scenario(s), %d echec(s)" % (lances, echecs))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
