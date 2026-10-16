#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Options communes des lancements de VICE pour les suites de test.

VICE garde ses reglages dans ~/.config/vice/vicerc et, avec
SaveResourcesOnExit, les reecrit a chaque sortie. Une session graphique
peut donc y laisser des ROMs qui n'ont rien a voir avec la machine de
reference -- le proprietaire y charge ses EPROM EDEX pour regarder le
rendu reel, par exemple. Les suites de test, elles, doivent toujours
juger sur la 8296 d'origine : si l'image ou l'editeur change sous elles,
soit VICE refuse de demarrer (ROM introuvable), soit la relecture de
l'ecran compare des glyphes qui ne sont plus les memes.

D'ou ces options, posees devant tout lancement : elles nomment
explicitement le generateur de caracteres et l'editeur standard, et
vident le module ROM optionnel en $A000.

Si une installation de VICE porte d'autres noms de fichiers, la variable
d'environnement PET_CHARGEN / PET_EDITOR permet de les donner.
"""

import os

CHARGEN = os.environ.get("PET_CHARGEN_NOM", "characters-2.901447-10.bin")
EDITEUR = os.environ.get("PET_EDITOR_NOM", "edit-4-80-b-50Hz.901474-04_.bin")

# A placer juste apres "xpet". Les options de la ligne de commande
# primant sur le fichier de configuration, elles suffisent a isoler le
# test des reglages de l'utilisateur.
#
# +saveres vaut autant que le reste : sans lui, VICE reecrit son vicerc
# en sortant -- il y enregistrerait les ROMs standard forcees ici, donc
# effacerait les EPROM EDEX que le proprietaire y avait reglees. Une
# suite de test ne doit rien laisser derriere elle.
#
# Le delai du tampon clavier est epingle pour la meme raison : les
# scenarios de test l'ont valide a 400, et il ne doit pas dependre de ce
# qui traine dans le vicerc de la machine.
ROMS_STANDARD = [
    "-chargen", CHARGEN,
    "-editor", EDITEUR,
    "-romA", "",
    "-keybuf-delay", "400",
    "+saveres",
]


def commande(*suite):
    """La commande xpet d'un essai sur 8296 standard, options en premier."""
    return ["xpet", "-model", "8296"] + ROMS_STANDARD + list(suite)
