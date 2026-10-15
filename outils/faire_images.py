#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique les images disquette et cassette a partir de echecs.prg.

    python3 outils/faire_images.py [--sans-essai]

Produit echecs.d64 (par c1541, livre avec VICE) et echecs.tap, les deux
formats que demande une release : disquette 1541/4040 d'un cote,
Tapuino ou magnetophone de l'autre.

Le .d64 ne demande qu'un appel a c1541. Le .tap, lui, est ecrit ici, car
VICE ne fournit pas d'outil pour en creer. Ce n'est pas un format de
fichier mais l'enregistrement des impulsions d'une bande : il faut donc
reproduire l'encodage cassette de Commodore, le meme sur PET, VIC et
C64.

Un bit vaut deux impulsions : court puis moyen pour un 0, moyen puis
court pour un 1. Un octet commence par un marqueur long + moyen, puis
ses huit bits du plus faible au plus fort, puis un bit de parite impaire.
Un bloc s'annonce par un long silence d'impulsions courtes, puis neuf
octets de compte a rebours ($89..$81 pour la premiere copie, $09..$01
pour la seconde), ses donnees, et leur somme de controle par ou exclusif.
Tout est ecrit deux fois : le KERNAL relit la seconde copie si la
premiere passe mal, ce qui etait precieux sur une bande usee.

Un fichier PRG tient en deux blocs : l'en-tete, qui donne le nom et les
adresses, puis les donnees.

Les trois durees (352, 512 et 680 cycles) sont celles relevees sur une
image produite pour cette machine ; le format TAP les compte par huit.

Les deux images sont ensuite chargees dans VICE pour verifier qu'elles
lancent bien le jeu : une bande mal encodee ne se voit pas autrement.
"""

import os
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRG = os.path.join(RACINE, "echecs.prg")
D64 = os.path.join(RACINE, "echecs.d64")
TAP = os.path.join(RACINE, "echecs.tap")
NOM_CBM = "ECHECS"

# Durees d'impulsion, en unites TAP de huit cycles
COURT, MOYEN, LONG = 44, 64, 85

# Silences d'amorce, en nombre d'impulsions courtes. Les valeurs sont
# celles d'une image qui charge sur cette machine : une longue amorce
# devant chaque bloc, le temps que le moteur prenne sa vitesse, et un
# court intervalle entre les deux copies d'un meme bloc.
AMORCE_DEBUT = 0x6A00       # avant l'en-tete
AMORCE_DONNEES = 0x1500     # avant les donnees
AMORCE_COPIE = 80           # entre les deux copies d'un bloc

# Type 1 : programme BASIC, ce que cherche un LOAD sans parametre. Le
# type 3, qui impose l'adresse de chargement, demanderait LOAD"nom",1,1
# et ne se lance pas tout seul.
TYPE_PRG = 1
TAILLE_ENTETE = 192


def bit(b):
    return [MOYEN, COURT] if b else [COURT, MOYEN]


def octet(v):
    """Marqueur de debut, huit bits du plus faible au plus fort, parite."""
    impulsions = [LONG, MOYEN]
    parite = 1
    for i in range(8):
        b = (v >> i) & 1
        impulsions += bit(b)
        parite ^= b
    return impulsions + bit(parite)


def bloc(donnees, premiere_copie, amorce):
    """Un bloc complet : amorce, compte a rebours, donnees, controle."""
    impulsions = [COURT] * amorce
    base = 0x80 if premiere_copie else 0x00
    for i in range(9, 0, -1):
        impulsions += octet(base | i)
    controle = 0
    for v in donnees:
        impulsions += octet(v)
        controle ^= v
    impulsions += octet(controle)
    impulsions += [LONG, COURT]     # fin de bloc
    return impulsions


def entete(nom, debut, fin):
    """Les 192 octets qui annoncent le fichier."""
    h = [TYPE_PRG,
         debut & 0xFF, debut >> 8,
         fin & 0xFF, fin >> 8]
    nom = nom.upper()[:16]
    h += [ord(c) for c in nom]
    h += [0x20] * (16 - len(nom))       # le nom tient sur seize caracteres
    h += [0x20] * (TAILLE_ENTETE - len(h))
    assert len(h) == TAILLE_ENTETE
    return h


def faire_tap(prg, chemin, nom):
    donnees = open(prg, "rb").read()
    debut = donnees[0] | (donnees[1] << 8)      # les deux premiers octets
    corps = list(donnees[2:])                   # sont l'adresse de chargement
    fin = debut + len(corps)

    tete = entete(nom, debut, fin)
    impulsions = []
    impulsions += bloc(tete, True, AMORCE_DEBUT)
    impulsions += bloc(tete, False, AMORCE_COPIE)
    impulsions += bloc(corps, True, AMORCE_DONNEES)
    impulsions += bloc(corps, False, AMORCE_COPIE)

    with open(chemin, "wb") as f:
        f.write(b"C64-TAPE-RAW")
        f.write(bytes([1, 0, 0, 0]))            # version 1
        f.write(len(impulsions).to_bytes(4, "little"))
        f.write(bytes(impulsions))
    return debut, fin, len(impulsions)


def faire_d64(prg, chemin, nom):
    if os.path.exists(chemin):
        os.remove(chemin)
    r = subprocess.run(
        ["c1541", "-format", "%s,01" % nom.lower(), "d64", chemin,
         "-write", prg, nom.lower()],
        capture_output=True, text=True)
    if r.returncode:
        print(r.stdout + r.stderr)
        return False
    return True


def essayer(image):
    """Charge l'image dans VICE et regarde si le jeu demarre vraiment.

    Une image mal formee se reconnait mal a l'oeil nu : le .tap n'est pas
    un fichier mais l'enregistrement d'une bande, et la moindre erreur
    d'encodage laisse le KERNAL chercher dans le vide. Le seul juge est
    donc un vrai chargement, impulsion par impulsion.
    """
    sys.path.insert(0, os.path.join(RACINE, "outils"))
    from lire_ecran import lire_grille, symbole
    import tempfile
    with tempfile.TemporaryDirectory() as dossier:
        capture = os.path.join(dossier, "essai.png")
        subprocess.run(
            ["xpet", "-model", "8296", "-autostart", image,
             "-limitcycles", "500000000", "-exitscreenshot", capture,
             "-warp", "+sound"],
            capture_output=True, timeout=1800)
        if not os.path.exists(capture):
            return "VICE n'a rien rendu"
        grille, _ = lire_grille(capture)
        ecran = "\n".join("".join(symbole(c) for c in l) for l in grille)
    if "QUEL JEU DE CARACTERES" not in ecran:
        premieres = [l.rstrip() for l in ecran.split("\n")[:10] if l.strip()]
        return "le jeu n'a pas demarre ; ecran : %s" % " | ".join(premieres)
    return None


def main():
    if not os.path.exists(PRG):
        print("echecs.prg absent : lancer d'abord "
              "64tass --cbm-prg -o echecs.prg main.asm")
        return 1
    if not faire_d64(PRG, D64, NOM_CBM):
        print("c1541 a echoue")
        return 1
    print("%-14s %7d octets" % (os.path.basename(D64),
                                os.path.getsize(D64)))
    debut, fin, n = faire_tap(PRG, TAP, NOM_CBM)
    print("%-14s %7d octets  (%d impulsions, $%04X-$%04X)"
          % (os.path.basename(TAP), os.path.getsize(TAP), n, debut, fin))
    if "--sans-essai" in sys.argv:
        return 0
    echecs = 0
    for image in (D64, TAP):
        probleme = essayer(image)
        if probleme:
            print("ECHEC  %-14s %s" % (os.path.basename(image), probleme))
            echecs += 1
        else:
            print("ok     %-14s le jeu demarre" % os.path.basename(image))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
