# Jeu d'échecs pour Commodore 8296 — CLAUDE.md

## Langue

Toujours répondre en **français** (explications, commentaires dans le code, messages de commit).

## Objectif

Un jeu d'**échecs** entièrement écrit en **assembleur 6502** pour un **Commodore 8296**, avec :

- de grandes pièces dessinées en **quarts de bloc PETSCII** (style Microchess), échiquier plein
  écran sur l'affichage 80×25 ;
- une **version EDEX** pour la ROM de caractères française de la machine du propriétaire ;
- le déplacement des pièces **au curseur** ;
- un **retour en arrière** (annulation des coups) ;
- **plusieurs niveaux** de jeu ;
- aucune modification matérielle : le programme doit tourner sur la machine telle quelle.

Ce projet fait suite au **jeu de dames** du même auteur (dépôt GitHub `fabrice35860-web/dames-8296`) :
reprendre son infrastructure (écran de choix de ROM, calibrage, lecture clavier, build, VICE, `.tap`)
plutôt que la réécrire.

## Machine cible

- **Commodore 8296** : CPU 6502 à 1 MHz, BASIC 4.0, écran 80×25 monochrome (moniteur intégré).
- **Mémoire écran** : `$8000`–`$87CF` (adresse = `$8000 + ligne*80 + colonne`).
- **CRTC** : MOS 6545‑1. **Ne pas reprogrammer le CRTC** (risque pour le moniteur intégré).
- **Mode caractères** : `$E84C` ← `#12` = majuscules + graphiques, `#14` = minuscules/majuscules
  (`POKE 59468,12` / `POKE 59468,14`).
- **RAM utilisateur** : `$0400`–`$7FFF`.
- **RAM étendue** : 64 Ko supplémentaires commutables sur `$8000`–`$FFFF` via le registre en
  `$FFF0` (écriture seule ; l'écran et les E/S doivent rester visibles). Reprendre la routine de
  commutation du jeu de dames si elle existe, sinon la documenter précisément avant usage.
  Usage : table de transpositions, bibliothèque d'ouvertures.
- **Kernal** : lecture clavier via `GETIN` (`JSR $FFE4`).
- **Page zéro** : zone empruntée `$B0`–`$C3` (20 octets), la zone de travail de la cassette.
  **Ne pas déborder au-delà de `$C3`** : `$C4`–`$C6` appartiennent à l'éditeur d'écran du KERNAL
  (pointeur de ligne, colonne du curseur). Les écraser ne gêne pas le jeu, qui écrit lui-même dans
  la mémoire écran, mais casse `CHROUT` — donc l'affichage de `perft.prg` et `test_ia.prg`, et le
  `ready.` du retour au BASIC. Seuls les pointeurs occupent la page zéro ; les octets simplement
  temporaires sont en RAM ordinaire.
  Mesure faite dans VICE pour le jeu de dames : en laissant tourner les interruptions plusieurs
  secondes, `$B0`–`$CA` restent intacts, tandis que `$F8`–`$FA` sont modifiés par le système
  (table des lignes écran de l'éditeur). La zone est sauvegardée au démarrage et rendue à la
  sortie (`sauver_pz` / `rendre_pz`). Répartition dans `constantes.asm`.
  *TODO machine réelle* : vérifier qu'après une partie, LOAD et SAVE cassette fonctionnent
  encore — l'EPROM EDEX 8000 est un éditeur modifié.

## Trois versions d'affichage

La machine du propriétaire a une ROM de caractères française (« AZ‑E‑Ø1 GEN. ») et un éditeur
modifié (« EDEX 8000 »). **Ne jamais supposer qu'on peut changer les ROMs.**

**Le générateur de caractères n'est pas lisible par le processeur** : il est câblé au circuit
vidéo, hors de l'espace d'adressage. Aucun programme ne peut donc l'inspecter, ni le remplacer —
il faut afficher et regarder. C'est pourquoi le choix se fait à l'œil, sur échantillon.

Au démarrage, reprendre l'**écran de choix** du jeu de dames : trois échantillons côte à côte,
« 1 - STANDARD », « 2 - EDEX », « 3 - LETTRES » ; présélection automatique par lecture de
l'éditeur en `$E000`, RETURN pour valider. Libellés de cet écran en lettres sans accent
uniquement. Le choix reste modifiable depuis le menu (touche `M`).

Toutes les routines de dessin passent par **une table de correspondance unique** (codes écran),
remplie selon le préréglage choisi. Le préréglage porte aussi **l'adresse des deux tables de
pièces** (blanches et noires) : rien ne distingue, dans `dessiner_piece`, les silhouettes en
quarts de bloc des pièces EDEX — ce sont douze codes écran à poser dans les deux cas.

### 1 — Version ROM STANDARD (VICE et PET standard)

Pièces en quarts de bloc (voir plus bas), cases claires en damier `▒`.

### 2 — Version EDEX (machine réelle), mode graphique `#12`

En mode graphique, la ROM EDEX **n'a pas** les quarts de bloc, les demi-blocs ni le damier `▒`
(codes 97–127 standard remplacés par des cadres et des accents). Les pièces y sont donc dessinées
avec les formes dont elle dispose. Codes **validés sur la vraie machine** :

| Forme | Code |
|---|---|
| ◤ coin haut-gauche | 81 |
| ◥ coin haut-droit | 65 |
| ◢ coin bas-droit | 209 |
| ◣ coin bas-gauche | 193 |
| █ bloc plein | 160 |
| ╭ ╮ ╰ ╯ petites courbes | 82, 84, 70, 71 |
| ─ trait horizontal | 102 |
| │ trait vertical | 97 |
| ┌ ┐ └ ┘ coins du cadre | 104, 106, 98, 100 |
| accents § à è ì ò ù â ê î ô û Ä Ö Ü ß é | 112 à 127 |
| vidéo inverse | code + 128 (comme la ROM standard) |

Les six pièces, 4×3 caractères aux colonnes 1–4 de la case, lues ligne par ligne. Ce sont des
**codes écran directs**, pas des masques de quarts : ils ne se calculent pas depuis un dessin en
pixels, ils sont donnés tels quels dans `outils/generer_pieces.py`.

```
roi      :  32,103,101, 32,  32,160,160, 32, 209,160,160,193
dame     : 209,193,209,193,  65,160,160, 81, 209,160,160,193
tour     : 160, 88, 88,160,  65,160,160, 81, 209,160,160,193
fou      :  32,209,193, 32,  32, 65, 81, 32, 209,160,160,193
cavalier :  32,209,160,193, 160, 81,160, 32, 209,160,160,193
pion     :  32, 32, 32, 32,  32,209,193, 32, 209,160,160,193
```

Pièces blanches : ces codes tels quels. Pièces noires : chaque code inversé (`code XOR 128`), soit
la silhouette sombre dans un rectangle allumé — et, comme pour les quarts, inverser toute la case
sous le curseur revient à échanger les deux tables.

Cases claires EDEX : caractère `.` (code 46). Cases foncées : vides (32). Le rectangle 4×3 de la
pièce remplace le remplissage de la case.

**VICE ne permet pas de juger ce rendu** : il n'a que la ROM standard, où ces numéros désignent
d'autres glyphes. Ce que les tests vérifient, et qui suffit, c'est que le programme écrit les bons
codes aux bons endroits (`test_pieces_edex` dans `outils/test_affichage.py`).

### 3 — Repli « lettres encadrées »

Chaque pièce est sa lettre française dans un cadre arrondi, sur 3×3 caractères aux colonnes 1–3
de la case :

```
╭─╮
│R│
╰─╯
```

Cases claires en pointillé (caractère `.`, code 46) au lieu du damier. Ce repli ne demande que des
traits et des coins, que toute ROM possède : c'est le choix de secours si les deux autres ne
donnent rien de lisible.

Le fichier `characters.901447-azerty.bin` qui traîne dans le dépôt des dames n'est **pas** l'EPROM
du propriétaire : ses codes 97, 98 et 100 sont encore des quarts de bloc, alors que sa machine y a
`│`, `└` et `┘`. Ne pas s'en servir pour trancher quoi que ce soit.

## Disposition de l'écran (validée sur maquette)

Les caractères du moniteur sont environ 2,4 fois plus hauts que larges : une case de **6×3**
caractères paraît à peu près carrée. L'échiquier occupe **toute la hauteur** de l'écran.

```
Échiquier    : case (rangée r = 0..7 depuis le haut, colonne c = 0..7)
               -> x0 = 2 + c*6, y0 = r*3   (colonnes 2–49, lignes 0–23)
               rangée 8 en haut (Noirs), rangée 1 en bas (Blancs)
               a8 = case claire ; case claire si (r + c) pair
Coordonnées  : chiffres 8..1 en colonne 0, ligne y0+1 ;
               lettres A..H en ligne 24, colonne x0+3
Panneau      : colonnes 51–79 (en-têtes en vidéo inverse sur colonnes 51–79, texte à partir de 52)
               ligne 0    : "JEU D'ÉCHECS   CBM 8296" (inverse)
               lignes 2–5 : TRAIT / ORDI / NIVEAU / PENDULE
               ligne 7    : en-tête "PARTIE", coups lignes 8–9 (les derniers coups)
               ligne 10   : en-tête "PIÈCES PRISES", ligne 11
               ligne 13   : en-tête "LÉGENDE", lignes 14–18
                            "R ROI  D DAME  T TOUR" / "F FOU  C CAVALIER" / "P PION" /
                            "LUMINEUX = BLANCS" / "SOMBRE = NOIRS"
               lignes 20–21 : message (ex. "CAVALIER G1 SÉLECTIONNÉ" / "DESTINATION ?")
               ligne 22   : saisie "VOTRE COUP : CG1-" + curseur clignotant
               ligne 23   : "CURSEUR : E2", la case pointée (utile au joueur et aux tests)
               ligne 24   : "U=ANNUL ?=AIDE N=NOUV Q=FIN"
```

- **Cases claires** : damier `▒` (version standard). **Cases foncées** : vides.
- **Pièce** : 4×3 caractères aux colonnes 1–4 de la case (`x0+1`…`x0+4`, `y0`…`y0+2`). Le rectangle
  4×3 de la pièce efface le damier.
- **Pièce blanche** : silhouette **lumineuse** sur fond sombre.
- **Pièce noire** : même silhouette **sombre** dans un rectangle **allumé** (tous les quarts inversés).
- Textes en majuscules ; accents (codes 112–127) seulement en version EDEX, sinon lettres sans accent.

### Dessin des pièces (validé sur maquette)

Chaque pièce est une grille de **8×6 « pixels »** ; chaque caractère couvre 2×2 pixels (un quart
de bloc par pixel). `#` = allumé (pièce blanche).

```
Roi (R)     Dame (D)    Tour (T)    Fou (F)     Cavalier (C) Pion (P)
...##...    #..##..#    ##.##.##    ...##...    ...#.#..     ........
.######.    ##.##.##    ########    ..##.#..    ..#####.     ...##...
...##...    .######.    .######.    ..####..    .######.     ..####..
..####..    ..####..    ..####..    ...##...    ##..###.     ...##...
..####..    ..####..    ..####..    ..####..    ...####.     ..####..
.######.    .######.    .######.    .######.    .######.     .######.
```

Conversion : pour le caractère (cx = 0..3, cy = 0..2), lire les pixels
(2cx, 2cy)=bit 1, (2cx+1, 2cy)=bit 2, (2cx, 2cy+1)=bit 4, (2cx+1, 2cy+1)=bit 8. Pour une pièce
noire, `masque = masque XOR 15`. Les grilles sont des **données** (`donnees.asm`) ; les 12 caractères
d'une pièce sont **précalculés** à l'assemblage (script Python dans `outils/`), pas à l'exécution.

Codes écran PETSCII des 16 combinaisons de quarts (ROM standard, mode `#12`) — **vérifiés** en
lisant le générateur de caractères de VICE (`outils/verifier_quarts.py` sur
`characters-2.901447-10.bin`) : les seize masques existent, dans les deux jeux (`#12` et `#14`), et
la table ci-dessous est exacte.

| Masque | Forme | Code | Masque | Forme | Code |
|---|---|---|---|---|---|
| 0 | vide | 32 | 8 | ▗ | 108 |
| 1 | ▘ | 126 | 9 | ▚ | 127 |
| 2 | ▝ | 124 | 10 | ▐ | 225 (inv. 97) |
| 3 | ▀ | 226 (inv. 98) | 11 | ▜ | 251 (inv. 123) |
| 4 | ▖ | 123 | 12 | ▄ | 98 |
| 5 | ▌ | 97 | 13 | ▙ | 252 (inv. 124) |
| 6 | ▞ | 255 (inv. 127) | 14 | ▟ | 254 (inv. 126) |
| 7 | ▛ | 236 (inv. 108) | 15 | █ | 160 |

Damier `▒` : code 102.

## Commandes

### Curseur

- Le curseur fait clignoter **toute la case 6×3** (inversion vidéo, ~2 Hz).
- **Flèches** : déplacement d'une case (gauche, droite, haut, bas), sans sortir de l'échiquier.
  Sur le clavier « business » de la 8296, les flèches sont deux touches CRSR (↓ et →) ; ↑ et ←
  s'obtiennent avec SHIFT. Codes `GETIN` attendus : ↓ 17, ↑ 145, → 29, ← 157 — **à vérifier**, et
  à placer en constantes dans `constantes.asm` (l'éditeur EDEX pourrait renvoyer d'autres codes).
- **Pavé numérique** en doublon : 8/2/4/6 = haut/bas/gauche/droite, 7/9/1/3 = diagonales.
- Position de départ du curseur : la dernière pièce jouée par le joueur, sinon la case E2.

### Sélection (RETURN, ESPACE en doublon)

1. Sur une pièce du joueur : **sélection** (marquage fixe : colonnes 0 et 5 de la case inversées,
   effet de crochets) ; les **destinations légales** sont marquées (petit motif au centre des cases
   vides, clignotement des pièces prenables).
2. Sur la pièce déjà sélectionnée : **désélection**.
3. Sur une autre pièce du joueur : changement de sélection.
4. Sur une destination légale : le coup est joué. Sur une case illégale : message
   « COUP IMPOSSIBLE » et la sélection reste active.
- Une pièce sans coup légal ne peut pas être sélectionnée (message « AUCUN COUP POUR CETTE PIÈCE »).
- **Promotion** : menu dans le panneau « PROMOTION : D T F C » (touche de la lettre), dame par défaut
  avec RETURN.
- La saisie en notation est conservée : taper une lettre ou un chiffre bascule en mode saisie
  (`CG1-F3`, `E2-E4`, roque `O-O` / `O-O-O`).

### Autres touches

- **J** = camp tenu par l'ordinateur : AUCUN → NOIRS → BLANCS → AUCUN.
- **U = annuler** (retour en arrière) : annule le dernier coup du joueur **et** la réponse de
  l'ordinateur (on revient à la position où c'était au joueur de jouer). Répétable jusqu'au début de
  la partie. Historique d'au moins 300 demi-coups.
- **N** = nouvelle partie (avec confirmation). **Q** = quitter (avec confirmation).
- **?** = aide (écran listant les touches).
- **L** = changer de niveau (entre deux coups).
- Pendant la réflexion de l'ordinateur : indicateur « RÉFLEXION… » et profondeur atteinte dans le
  panneau ; **STOP** force l'ordinateur à jouer le meilleur coup trouvé.

## Niveaux

Choix du niveau au menu de départ et en cours de partie (touche L). Valeurs initiales **à calibrer**
dans VICE (en vitesse réelle 1 MHz) :

| Niveau | Recherche | Temps max par coup |
|---|---|---|
| 1 Débutant | 1 demi-coup + recherche de calme | instantané |
| 2 Facile | 2 demi-coups | ~5 s |
| 3 Moyen | 3 demi-coups | ~15 s |
| 4 Confirmé | approfondissement itératif | 30 s |
| 5 Fort | approfondissement itératif | 1 min |
| 6 Maximum | approfondissement itératif | 3 min |

Les niveaux 1 et 2 ajoutent un peu de hasard au choix entre coups de valeur proche, pour ne pas
toujours jouer la même partie. Bibliothèque d'ouvertures active à partir du niveau 3.

## Règles (FIDE)

Déplacements des 6 pièces, **roque** (petit et grand, conditions complètes : roi et tour jamais
déplacés, cases libres, roi ni en échec ni traversant/arrivant sur une case attaquée), **prise en
passant**, **promotion** au choix, **échec**, **mat**, **pat**, **règle des 50 coups**,
**triple répétition** (via hachage de position), **matériel insuffisant**. Un coup qui laisse son
roi en échec est illégal.

Notation affichée dans le panneau : lettre française de la pièce + départ-arrivée
(`CG1-F3`, `E2-E4`, `FF1XB5` pour une prise, `O-O`), comme sur la maquette.

## Architecture du code

- **Assembleur** : 64tass. `.prg` chargé en `$0401`, ligne BASIC `10 SYS1040`, code en `$0410`.
- **Carte mémoire** : programme et données à partir de `$0401` ; zones de travail à adresse fixe
  au-delà de `DEBUT_ZONES = $5000` (elles ne sont pas dans le `.prg`) : historique de la partie
  `$5000` (400 demi-coups de 8 octets), listes de coups de la recherche `$6000`–`$7BFF`.
  `main.asm` vérifie à l'assemblage que le programme ne rattrape pas `$5000`.
- **Organisation des sources** : `main.asm` inclut `constantes.asm` puis `ecran.asm`,
  `ecran_rom.asm`, `clavier.asm`, `coups.asm`, `regles.asm`, `evaluation.asm`, `recherche.asm`,
  `donnees.asm`, et les fichiers **générés** `donnees_tables.asm`, `donnees_pieces.asm` et
  `donnees_eval.asm` (ne pas les éditer à la main).
  `coups.asm`, `evaluation.asm` et `recherche.asm` ne touchent jamais l'écran : `perft.asm` et
  `test_ia.asm`, les deux programmes de validation, les reprennent tels quels avec
  `donnees_regles.asm` (l'état de la partie et les variables du moteur) et s'en tiennent à
  `CHROUT` pour écrire leurs résultats.
- **Un coup tient sur quatre octets** : départ, arrivée, drapeau (double pas, prise en passant,
  roque, promotion), note de tri. Les coups d'un demi-coup exploré sont rangés à la suite à partir
  de `coups_fin`, qui avance ; chaque niveau garde le début de sa tranche et la rend en repartant.
- **Plateau 0x88** (128 octets) : test hors échiquier par `AND #$88`. Listes de pièces par camp
  pour éviter de balayer tout le plateau.
- **Jouer/annuler sur place** (make/unmake) avec pile d'annulation ; la même pile sert au
  **retour en arrière** du joueur.
- **Générateur de coups** pseudo-légaux + test d'échec du roi ; générateur séparé « prises
  seulement » pour la recherche de calme.
- **Recherche** : alpha-bêta (négamax), approfondissement itératif limité par le temps (jiffies),
  **recherche de calme** (prises), tri des coups : coup de la table de transpositions, prises
  MVV‑LVA, coups « killer ».
- **Table de transpositions** en RAM étendue, hachage **Zobrist** (clé 16 ou 24 bits à décider) ;
  le même hachage sert à la triple répétition.
- **Bibliothèque d'ouvertures** en RAM étendue, **construite au démarrage** à partir de données
  compactes incluses dans le `.prg` (le `.prg` ne doit jamais dépasser `$7FFF`).
- **Évaluation** : matériel (P 100, C 320, F 330, T 500, D 900), tables position par pièce,
  structure de pions simple, sécurité du roi en milieu de partie, roi actif en finale.
- **Affichage** : redessiner uniquement les cases modifiées.
- Organisation : `main.asm`, `ecran.asm`, `clavier.asm`, `regles.asm`, `recherche.asm`,
  `evaluation.asm`, `ouvertures.asm`, `ram_etendue.asm`, `donnees.asm`, `constantes.asm`.
- Commentaires en français, labels explicites.

## Plan de travail

1. **Affichage** — *fait*. Écran de choix ROM, échiquier, pièces (version standard), panneau,
   curseur, sélection, saisie en notation, retour en arrière, aide.
2. **Règles** — *fait*. Générateur de coups complet (`coups.asm`), validation **perft** (17 valeurs
   de référence, 0 écart), marquage des destinations légales, mat, pat, règle des 50 coups,
   matériel insuffisant, triple répétition, promotion, roque, prise en passant, retour en arrière.
3. **IA** — *faite pour l'essentiel*. Alpha-bêta négamax (`recherche.asm`), recherche de calme,
   approfondissement itératif, tri MVV-LVA, six niveaux, STOP pour interrompre, évaluation
   matérielle et positionnelle (`evaluation.asm`).
   *Reste à faire* : table de transpositions et bibliothèque d'ouvertures en RAM étendue — elles
   attendent que la commutation par `$FFF0` soit vérifiée sur la vraie machine. Coups « killer »
   non implantés.
4. **Version EDEX** — *faite*. Pièces dessinées avec les formes de l'EPROM française (triangles
   d'angle et blocs pleins), codes relevés sur la vraie 8296, en mode graphique `#12`. Les trois
   versions sont proposées au démarrage. Reste à regarder le rendu sur la machine réelle.
5. **Finitions** : aide, pendule, menus, son (plus tard).

Valider chaque étape dans VICE puis sur la vraie machine. Faire un `/clear` entre deux étapes
(ce fichier est rechargé automatiquement).

## Outils et tests

- Installation : `sudo apt install vice 64tass` ; `pip install python-chess --break-system-packages`.
- Assemblage : `64tass --cbm-prg -o echecs.prg main.asm` (`-L echecs.lst` pour le listing).
- Test avec capture d'écran :
  ```
  xpet -default -model 8296 -autostart echecs.prg -limitcycles 20000000 -exitscreenshot ecran.png
  ```
  Regarder `ecran.png` après chaque modification de l'affichage.
- **Tests d'affichage** : `python3 outils/test_affichage.py [-v] [motif]` lance le jeu dans VICE
  pour chaque scénario, relit l'écran avec `outils/lire_ecran.py` et compare au texte attendu.
  Deux scénarios jugent les pixels : le battement du curseur et le marquage de la pièce choisie.
  Limite de `-keybuf` : il ne transmet ni les flèches ni DEL, et les lettres s'y écrivent en
  minuscules — ces touches-là restent à vérifier à la main.
- **Largeur des messages** : `python3 outils/verifier_textes.py` vérifie qu'aucun message du
  panneau ne dépasse `PAN_LT` (28 colonnes). Un message trop long ne se tronque pas : il continue
  sur la ligne suivante **colonne 0**, donc par-dessus l'échiquier — le défaut est discret (une
  coordonnée de rangée remplacée par une lettre). Ce contrôle tourne aussi au début de
  `test_affichage.py`.
- **Vérification des quarts de bloc** : `python3 outils/verifier_quarts.py <chargen.bin>` dit quels
  codes donnent chacun des seize masques, en vidéo normale comme inverse.
- **Validation perft** : `python3 outils/test_perft.py` assemble puis lance `perft.prg` dans VICE
  et compare aux valeurs de l'oracle (`outils/generer_perft.py` les recalcule avec python-chess).
  Comptez une à deux minutes. Valeurs vérifiées :
  - position initiale : 20 / 400 / 8 902 / 197 281 (profondeurs 1 à 4) ;
  - « Kiwipete » `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -` :
    48 / 2 039 / 97 862 (profondeurs 1 à 3) ;
  - ajouter des positions de roque, prise en passant et promotion.
  Les cinq positions (initiale, Kiwipete, finale, promotions, position encombrée) passent sans
  écart.
- **Test de l'adversaire** : `python3 outils/test_ia.py` lance `test_ia.prg` sur six positions où
  le bon coup ne fait aucun doute (mat en un, reprise, dame à sauver, pion franc, promotion) et
  compare au coup attendu. Un échec vient de la recherche ou de l'évaluation, jamais du générateur
  de coups — celui-là, c'est perft qui le juge.
- **Oracle** : `outils/generer_perft.py` et `outils/generer_ia.py` (python-chess) produisent les
  positions de test et les valeurs attendues ; ils vérifient aussi que les coups attendus sont
  légaux.
- **Images de disquette et de cassette** : `python3 outils/faire_images.py` produit `echecs.d64`
  (par `c1541`) et `echecs.tap`, puis charge les deux dans VICE pour vérifier qu'elles lancent le
  jeu. Le `.tap` est écrit par le script, VICE n'ayant pas d'outil pour en créer : ce n'est pas un
  fichier mais l'enregistrement des impulsions d'une bande. Deux points coûtent cher à retrouver :
  le **type de fichier doit être 1** (programme BASIC) — avec le type 3, un `LOAD` simple cherche
  dans le vide — et les durées d'impulsion du PET sont **352, 512 et 680 cycles** (44, 64 et 85 en
  unités TAP), pas celles du C64.
- Les fichiers générés se refont par `python3 outils/generer_pieces.py`,
  `generer_tables.py` (dessins et géométrie), `generer_eval.py` (tables de position),
  `generer_perft.py` et `generer_ia.py` (positions de test).
- Le propriétaire teste sur la **vraie 8296** : garder un `.prg` à jour et lui dire ce qui doit être
  vérifié sur machine réelle (version EDEX, touches curseur).

## Publication

Dépôt GitHub `fabrice35860-web/echecs-8296`, licence comme le jeu de dames. Ne jamais inclure de
ROM Commodore. Les trois fichiers `.prg`, `.d64`, `.tap` sont **suivis dans `dist/`**, pour être
visibles dans l'arborescence du dépôt, et joints en plus à chaque release. `outils/faire_images.py`
remplit `dist/` entièrement : il y recopie le `.prg` et y écrit les deux images, de sorte que les
trois sortent du même assemblage. `.gitignore` exclut ces noms partout ailleurs, avec trois
contre-règles `!dist/...` à la fin.

## Questions ouvertes

- Les pièces EDEX sont-elles lisibles sur la vraie 8296 ? Les codes viennent de la photo de la
  galerie, mais le dessin complet n'a pas encore été vu à l'écran.
- Codes réels des flèches du curseur et du pavé numérique sous l'éditeur EDEX, à relever sur la
  vraie machine : il suffira de compléter `nav_touches` dans `donnees.asm`.
- **Vitesse et profondeur atteinte** — mesurées dans VICE, position après 1.e4 (32 pièces) :

  | Niveau | Temps accordé | Profondeur atteinte |
  |---|---|---|
  | 2 Facile | 5 s | 1 |
  | 3 Moyen | 15 s | 2 |
  | 4 Confirmé | 30 s | 3 |
  | 5 Fort | 60 s | 3 |
  | 6 Maximum | 3 min | 3 |

  Environ **36 000 cycles par position examinée**, soit une trentaine par seconde. En finale
  simplifiée (3 ou 4 pièces) le niveau 6 atteint la profondeur 5 à 8 en 20 000 nœuds.

  **Les niveaux 4, 5 et 6 jouent donc le même coup en milieu de partie** : la profondeur 4 est
  hors d'atteinte même en trois minutes. Ils ne se distinguent qu'en finale. C'est ce qu'il faut
  corriger en premier si l'on veut un adversaire plus fort. Par ordre de rendement :
  1. tenir une liste des pièces par camp, au lieu de balayer les 128 cases à chaque génération ;
  2. n'appeler `est_attaquee` après un coup que lorsque le roi peut réellement être en prise ;
  3. tenir le score matériel à jour au lieu de le recalculer à chaque feuille ;
  4. coups « killer » et table de transpositions, qui réduisent l'arbre plutôt que le coût du nœud.

  Mesures faites au niveau 6 sur les six positions de `test_ia.prg`, qui donnent une idée du coût
  selon la position : mat du couloir 144 nœuds (profondeur 2, la recherche s'arrête dès qu'un mat
  est vu), mat de la dame 229 (p. 2), reprise de dame 16 894 (p. 5), dame à sauver 19 467 (p. 4),
  pion franc 20 630 (p. 8), promotion 19 608 (p. 6). Une position pauvre coûte moins cher par
  nœud, d'où la profondeur bien plus grande en finale.

- **Force estimée : 1000 à 1200 Elo** — *estimation, pas mesure*. Elle découle de la profondeur
  atteinte (3 demi-coups plus la recherche de calme en milieu de partie), pas d'un match.

  Ce que la profondeur 3 permet et interdit : le programme ne laisse jamais une pièce en prise et
  ne perd pas d'échange, la recherche de calme l'en préserve ; il punit les gaffes simples et
  trouve les mats en un, souvent en deux ; mais **toute combinaison de trois coups le dépasse** —
  sacrifice suivi d'une fourchette, attaque à la découverte préparée, attraction. Il n'a aucun
  plan : son jugement positionnel se réduit aux tables de cases, aux pions doublés et isolés, et
  au roi qui se cache ou sort selon la phase. En finale il est relativement meilleur, la
  profondeur y étant deux fois plus grande, mais sans aucune connaissance de finale (opposition,
  règle du carré) hors ce que la recherche trouve d'elle-même.

  Repères historiques, en ordres de grandeur (les échelles de l'époque sont surtout USCF et les
  estimations varient d'une source à l'autre) :

  | Programme | Machine | Force estimée |
  |---|---|---|
  | Microchess (1976) | 6502, 1 Ko | 800–1000 |
  | Chess Challenger 7 (1979) | dédié | ~1100 |
  | **Ce programme** | **6502 à 1 MHz** | **1000–1200** |
  | Sargon II (1978-79) | Z80, puis 6502 sur Apple II | 1400–1500 |

  La comparaison qui compte est **Sargon II sur Apple II** : même processeur, même fréquence. Il
  était plus fort, et pour des raisons qu'on peut nommer — code de recherche plus économe,
  évaluation plus riche (mobilité, sécurité du roi), extensions tactiques. Nos 36 000 cycles par
  nœud sont le principal frein : c'est là que se gagneraient les points, pas dans l'évaluation.

  **Pour obtenir un vrai chiffre**, il faudrait un match contre un moteur calibré. Les briques
  existent : `outils/lire_ecran.py` sait lire le coup joué dans le panneau, `-keybuf` sait injecter
  les coups en notation, et python-chess peut arbitrer contre un adversaire bridé (Stockfish à
  faible `Skill Level`, ou fairymax). Reste à écrire le pont VICE ↔ UCI. Compter environ 2,5 s
  réelles par coup au niveau 6 en warp, donc ~2 min par partie et 4 à 5 heures pour une centaine
  de parties, ce qui donnerait un Elo à ±50 près.
- Un vrai écran de menu (celui du jeu de dames) reste à porter ; pour l'instant `M` ramène
  directement au choix du jeu de caractères, et `L` change le niveau en cours de partie.
- Le joueur choisit-il sa couleur (Blancs/Noirs) et l'orientation de l'échiquier ?
- Partie à deux joueurs humains en plus de la partie contre l'ordinateur ?
- Son (plus tard).

