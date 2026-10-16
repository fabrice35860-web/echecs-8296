#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fabrique les images disquette et cassette a partir de echecs.prg.

Les trois fichiers distribues (.prg, .d64, .tap) sont reunis dans dist/.

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
import shutil
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRG = os.path.join(RACINE, "echecs.prg")

# Les trois fichiers distribues sont reunis dans dist/, qui est suivi par
# git : c'est la que les utilisateurs les trouvent sans passer par une
# release. Le .prg y est recopie depuis la sortie de 64tass, pour que les
# trois soient toujours faits de la meme assise.
DIST = os.path.join(RACINE, "dist")
PRG_DIST = os.path.join(DIST, "echecs.prg")
D64 = os.path.join(DIST, "echecs.d64")
TAP = os.path.join(DIST, "echecs.tap")
NOM_CBM = "ECHECS"

# Durees d'impulsion, en unites TAP de huit cycles
COURT, MOYEN, LONG = 44, 64, 85

# Amorces, en nombre d'impulsions courtes. Une longue amorce devant
# chaque fichier, le temps que le moteur prenne sa vitesse, un court
# intervalle entre les deux copies d'un meme bloc, et surtout une amorce
# de queue derriere la derniere copie.
#
# Cette amorce de queue n'est pas un ornement. Sans elle, la bande
# s'arretait net sur le marqueur de fin du dernier bloc : VICE signale
# alors la fin de bande et son KERNAL conclut, mais une vraie 8296
# attend des fronts qui ne viennent plus, et le chargement n'aboutit
# pas. C'est le defaut qui rendait les images precedentes illisibles sur
# la machine reelle alors qu'elles passaient en emulation.
AMORCE_DEBUT = 0x6A00       # avant l'en-tete
AMORCE_DONNEES = 0x1500     # avant les donnees
AMORCE_COPIE = 80           # entre les deux copies d'un bloc
AMORCE_QUEUE = 80           # derriere la seconde copie

# Silences, en cycles. Celui de tete est le temps mort avant le premier
# bloc ; celui du milieu est l'arret du moteur entre l'en-tete et les
# donnees, que le KERNAL commande lui-meme. Les deux valeurs sont celles
# relevees sur un enregistrement fait par VICE sur une bande montee a la
# main (0,34 s), arrondies.
PAUSE_TETE = 340000
PAUSE_MILIEU = 340000

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


def fichier_tape(donnees, amorce):
    """Un fichier sur la bande : deux copies du bloc, amorce de queue.

    C'est la forme qu'ecrit le KERNAL : une longue amorce, la copie dite
    premiere, un court intervalle, la seconde copie, puis une amorce de
    queue pour que le lecteur ait de quoi finir son travail.
    """
    return (bloc(donnees, True, amorce)
            + bloc(donnees, False, AMORCE_COPIE)
            + [COURT] * AMORCE_QUEUE)


def ecrire_tap(chemin, elements):
    """Serialise une suite d'impulsions et de silences au format TAP v1.

    Une impulsion est un entier, un silence le couple ("pause", cycles).
    En version 1, un silence s'ecrit 0 suivi de sa duree sur trois octets
    de poids croissant. Le mot de l'en-tete compte des OCTETS de donnees,
    pas des impulsions : un silence en vaut quatre.
    """
    corps = bytearray()
    for e in elements:
        if isinstance(e, tuple):
            corps.append(0)
            corps += int(e[1]).to_bytes(3, "little")
        else:
            corps.append(e)
    with open(chemin, "wb") as f:
        f.write(b"C64-TAPE-RAW")
        f.write(bytes([1, 0, 0, 0]))            # version 1
        f.write(len(corps).to_bytes(4, "little"))
        f.write(bytes(corps))
    return sum(1 for e in elements if not isinstance(e, tuple))


def faire_tap(prg, chemin, nom):
    donnees = open(prg, "rb").read()
    debut = donnees[0] | (donnees[1] << 8)      # les deux premiers octets
    corps = list(donnees[2:])                   # sont l'adresse de chargement
    fin = debut + len(corps)

    tete = entete(nom, debut, fin)
    elements = [("pause", PAUSE_TETE)]
    elements += fichier_tape(tete, AMORCE_DEBUT)
    elements += [("pause", PAUSE_MILIEU)]       # le KERNAL arrete le moteur
    elements += fichier_tape(corps, AMORCE_DONNEES)

    n = ecrire_tap(chemin, elements)
    return debut, fin, n


# ---------------------------------------------------------------------
#  Relecture de la bande produite
#
#  VICE ne sait pas juger une bande : son emulation du lecteur pardonne
#  ce qu'un vrai 8296 refuse -- la fin de bande lui tient lieu de fin de
#  bloc. Le seul controle qui attrape ce genre de defaut est de relire
#  les impulsions ecrites et d'y retrouver la forme attendue.
# ---------------------------------------------------------------------
def lire_tap(chemin):
    """Rend la suite des elements d'un .tap : impulsions et silences."""
    d = open(chemin, "rb").read()
    if d[:12] != b"C64-TAPE-RAW":
        return None, "signature absente"
    annonce = int.from_bytes(d[16:20], "little")
    if annonce != len(d) - 20:
        return None, ("le mot de longueur annonce %d octets, le fichier en "
                      "porte %d" % (annonce, len(d) - 20))
    elements, i = [], 20
    while i < len(d):
        if d[i] == 0 and d[12] >= 1:
            elements.append(("pause", int.from_bytes(d[i+1:i+4], "little")))
            i += 4
        else:
            elements.append(d[i])
            i += 1
    return elements, None


def classer(v):
    """Une impulsion rendue a sa classe : courte, moyenne, longue."""
    if v <= (COURT + MOYEN) // 2:
        return "C"
    if v <= (MOYEN + LONG) // 2:
        return "M"
    return "L"


def decouper_tap(elements):
    """Decoupe en amorces (suites d'impulsions courtes), blocs, silences."""
    zones, i = [], 0
    while i < len(elements):
        e = elements[i]
        if isinstance(e, tuple):
            zones.append(("pause", e[1])); i += 1; continue
        j = i
        while (j < len(elements) and not isinstance(elements[j], tuple)
               and classer(elements[j]) == "C"):
            j += 1
        if j - i >= 16:
            zones.append(("amorce", j - i)); i = j; continue
        j = i
        while j < len(elements) and not isinstance(elements[j], tuple):
            if classer(elements[j]) == "C":
                k = j
                while (k < len(elements) and not isinstance(elements[k], tuple)
                       and classer(elements[k]) == "C"):
                    k += 1
                if k - j >= 16:
                    break
                j = k
                continue
            j += 1
        zones.append(("bloc", elements[i:j])); i = j
    return zones


def decoder_bloc(impulsions):
    """Les octets d'un bloc : marqueur L+M, huit bits, parite."""
    cl = [classer(v) for v in impulsions]
    octets, i = [], 0
    while i < len(cl) - 1:
        if cl[i] == "L" and cl[i+1] == "M":
            i += 2
            v, ok = 0, True
            for b in range(9):
                if i + 1 >= len(cl):
                    ok = False
                    break
                paire = (cl[i], cl[i+1])
                if paire == ("M", "C"):
                    n = 1
                elif paire == ("C", "M"):
                    n = 0
                else:
                    ok = False
                    break
                if b < 8:
                    v |= n << b
                i += 2
            if ok:
                octets.append(v)
        elif cl[i] == "L" and cl[i+1] == "C":
            i += 2                      # marqueur de fin de bloc
        else:
            i += 1
    return octets


def verifier_tap(chemin, prg, nom):
    """Relit la bande et dit ce qui ne va pas, ou None si tout va bien."""
    elements, souci = lire_tap(chemin)
    if souci:
        return souci
    zones = decouper_tap(elements)
    formes = [z[0] for z in zones]
    attendu = ["pause", "amorce", "bloc", "amorce", "bloc", "amorce",
               "pause", "amorce", "bloc", "amorce", "bloc", "amorce"]
    if formes != attendu:
        return "structure inattendue : %s" % " ".join(formes)
    # l'amorce de queue : celle qui suit la derniere copie de chaque fichier
    for rang in (5, 11):
        if zones[rang][1] < 20:
            return ("amorce de queue trop courte (%d impulsions) : une vraie "
                    "machine n'y trouverait pas de quoi finir le bloc"
                    % zones[rang][1])
    blocs = [decoder_bloc(z[1]) for z in zones if z[0] == "bloc"]
    for rang, b in enumerate(blocs):
        if len(b) < 11:
            return "bloc %d trop court : %d octets" % (rang + 1, len(b))
        contenu, controle = b[9:-1], b[-1]
        calcule = 0
        for v in contenu:
            calcule ^= v
        if calcule != controle:
            return ("controle du bloc %d faux : %02X au lieu de %02X"
                    % (rang + 1, controle, calcule))
        depart = b[0] & 0x0F
        if depart != 9:
            return "compte a rebours du bloc %d : %d au lieu de 9" % (rang + 1,
                                                                      depart)
    if blocs[0][9:-1] != blocs[1][9:-1] or blocs[2][9:-1] != blocs[3][9:-1]:
        return "les deux copies d'un bloc ne portent pas la meme chose"
    tete = blocs[0][9:-1]
    donnees = open(prg, "rb").read()
    debut = donnees[0] | (donnees[1] << 8)
    fin = debut + len(donnees) - 2
    if tete[0] != TYPE_PRG:
        return "type de fichier %d au lieu de %d" % (tete[0], TYPE_PRG)
    if (tete[1] | tete[2] << 8) != debut or (tete[3] | tete[4] << 8) != fin:
        return ("l'en-tete annonce $%04X-$%04X au lieu de $%04X-$%04X"
                % (tete[1] | tete[2] << 8, tete[3] | tete[4] << 8, debut, fin))
    ecrit = bytes(tete[5:21]).decode("latin1").rstrip(" ")
    if ecrit != nom:
        return "nom de fichier %r au lieu de %r" % (ecrit, nom)
    if bytes(blocs[2][9:-1]) != donnees[2:]:
        return "les donnees de la bande ne sont pas celles du .prg"
    return None


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
    from vice import ROMS_STANDARD
    import tempfile
    with tempfile.TemporaryDirectory() as dossier:
        capture = os.path.join(dossier, "essai.png")
        subprocess.run(
            ["xpet", "-model", "8296"] + ROMS_STANDARD
            + ["-autostart", image,
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
    if not os.path.isdir(DIST):
        os.mkdir(DIST)
    shutil.copyfile(PRG, PRG_DIST)
    print("%-14s %7d octets" % (os.path.basename(PRG_DIST),
                                os.path.getsize(PRG_DIST)))
    if not faire_d64(PRG, D64, NOM_CBM):
        print("c1541 a echoue")
        return 1
    print("%-14s %7d octets" % (os.path.basename(D64),
                                os.path.getsize(D64)))
    debut, fin, n = faire_tap(PRG, TAP, NOM_CBM)
    print("%-14s %7d octets  (%d impulsions, $%04X-$%04X)"
          % (os.path.basename(TAP), os.path.getsize(TAP), n, debut, fin))
    souci = verifier_tap(TAP, PRG, NOM_CBM)
    if souci:
        print("ECHEC  %-14s %s" % (os.path.basename(TAP), souci))
        return 1
    print("ok     %-14s relue : structure et donnees conformes"
          % os.path.basename(TAP))
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
