; =====================================================================
;  donnees.asm - textes, tables de textes et variables du jeu
; =====================================================================

.enc "screen"

; ---------------------------------------------------------------------
;  Textes fixes (codes ecran, termines par 0)
;  Les lettres accentuees passent par les marqueurs ACC_* : afficher_texte
;  leur donne la forme de la ROM active, ou la lettre sans accent.
; ---------------------------------------------------------------------
t_titre         .text "JEU D"
                .byte $27
                .byte ACC_E_AIGU
                .text "CHECS"
                .byte 0
t_machine       .text "CBM 8296"
                .byte 0

t_trait         .text "TRAIT  :"
                .byte 0
t_ordi          .text "ORDI   :"
                .byte 0
t_niveau        .text "NIVEAU :"
                .byte 0
t_pendule       .text "PENDULE:"
                .byte 0

t_h_partie      .text "PARTIE"
                .byte 0
t_h_prises      .text "PI"
                .byte ACC_E_GRAVE
                .text "CES PRISES"
                .byte 0
t_h_legende     .text "L"
                .byte ACC_E_AIGU
                .text "GENDE"
                .byte 0

t_leg1          .text "R ROI  D DAME  T TOUR"
                .byte 0
t_leg2          .text "F FOU  C CAVALIER"
                .byte 0
t_leg3          .text "P PION"
                .byte 0
t_leg4          .text "LUMINEUX = BLANCS"
                .byte 0
t_leg5          .text "SOMBRE = NOIRS"
                .byte 0

t_blancs        .text "BLANCS"
                .byte 0
t_noirs         .text "NOIRS"
                .byte 0
t_aucun         .text "AUCUN"
                .byte 0

t_votre         .text "VOTRE COUP : "
                .byte 0
t_touches       .text "U=ANNUL ?=AIDE N=NOUV Q=FIN"
                .byte 0
t_curseur       .text "CURSEUR : "
                .byte 0

; --- noms des pieces, pour le message de selection -------------------
t_pion          .text "PION"
                .byte 0
t_cavalier      .text "CAVALIER"
                .byte 0
t_fou           .text "FOU"
                .byte 0
t_tour          .text "TOUR"
                .byte 0
t_dame          .text "DAME"
                .byte 0
t_roi           .text "ROI"
                .byte 0
nom_piece_lo
        .byte <t_pion, <t_cavalier, <t_fou, <t_tour, <t_dame, <t_roi
nom_piece_hi
        .byte >t_pion, >t_cavalier, >t_fou, >t_tour, >t_dame, >t_roi

; --- noms des niveaux ------------------------------------------------
t_niv1          .text "D"
                .byte ACC_E_AIGU
                .text "BUTANT"
                .byte 0
t_niv2          .text "FACILE"
                .byte 0
t_niv3          .text "MOYEN"
                .byte 0
t_niv4          .text "CONFIRM"
                .byte ACC_E_AIGU
                .byte 0
t_niv5          .text "FORT"
                .byte 0
t_niv6          .text "MAXIMUM"
                .byte 0
niveau_nom_lo
        .byte <t_niv1, <t_niv2, <t_niv3, <t_niv4, <t_niv5, <t_niv6
niveau_nom_hi
        .byte >t_niv1, >t_niv2, >t_niv3, >t_niv4, >t_niv5, >t_niv6

; ---------------------------------------------------------------------
;  Messages des lignes 20 et 21 du panneau : 28 colonnes au plus
; ---------------------------------------------------------------------
t_m_nouvelle    .text "NOUVELLE PARTIE"
                .byte 0
t_m_a_blancs    .text "AUX BLANCS DE JOUER"
                .byte 0
t_m_a_noirs     .text "AUX NOIRS DE JOUER"
                .byte 0
t_m_select      .text "S"
                .byte ACC_E_AIGU
                .text "LECTIONN"
                .byte ACC_E_AIGU
                .byte 0
t_m_destination .text "DESTINATION ?"
                .byte 0
t_m_choisir     .text "CHOISISSEZ UNE PI"
                .byte ACC_E_GRAVE
                .text "CE"
                .byte 0
t_m_vide        .text "CASE VIDE"
                .byte 0
t_m_vos_pieces  .text "CHOISISSEZ UNE DE VOS PI"
                .byte ACC_E_GRAVE
                .text "CES"
                .byte 0
t_m_adverse     .text "CETTE PI"
                .byte ACC_E_GRAVE
                .text "CE EST "
                .byte ACC_A_GRAVE
                .byte 0
t_m_adverse2    .text "L"
                .byte $27
                .text "ADVERSAIRE"
                .byte 0
t_m_impossible  .text "COUP IMPOSSIBLE"
                .byte 0
t_m_saisie_nok  .text "SAISIE INVALIDE"
                .byte 0
t_m_rien_annul  .text "AUCUN COUP "
                .byte ACC_A_GRAVE
                .text " ANNULER"
                .byte 0
t_m_annule      .text "COUP ANNUL"
                .byte ACC_E_AIGU
                .byte 0
t_m_conf_nouv   .text "NOUVELLE PARTIE ?"
                .byte 0
t_m_conf_fin    .text "QUITTER LE JEU ?"
                .byte 0
t_m_conf_rep    .text "O = OUI, AUTRE = NON"
                .byte 0
t_m_roque_nok   .text "ROQUE IMPOSSIBLE"
                .byte 0
t_m_aucun_coup  .text "AUCUN COUP POUR CETTE PI"
                .byte ACC_E_GRAVE
                .text "CE"
                .byte 0
t_m_echec       .text "**  "
                .byte ACC_E_AIGU
                .text "CHEC AU ROI  **"
                .byte 0
t_m_mat         .text "**  "
                .byte ACC_E_AIGU
                .text "CHEC ET MAT  **"
                .byte 0
t_m_pat         .text "PAT - PARTIE NULLE"
                .byte 0
t_m_nulle50     .text "NULLE : R"
                .byte ACC_E_GRAVE
                .text "GLE DES 50 COUPS"
                .byte 0
t_m_nulle_mat   .text "NULLE : MAT"
                .byte ACC_E_AIGU
                .text "RIEL INSUFFISANT"
                .byte 0
t_m_nulle_rep   .text "NULLE : TRIPLE R"
                .byte ACC_E_AIGU
                .text "P"
                .byte ACC_E_AIGU
                .text "TITION"
                .byte 0
t_m_gagnent     .text " GAGNENT"
                .byte 0
t_note_petit    .text "O-O   "
t_note_grand    .text "O-O-O "
t_m_reflexion   .text "R"
                .byte ACC_E_AIGU
                .text "FLEXION... "
                .byte 0
t_m_stop        .text "STOP POUR JOUER MAINTENANT"
                .byte 0
t_m_promotion   .text "PROMOTION : D T F C"
                .byte 0
t_m_promo2      .text "RETURN POUR LA DAME"
                .byte 0
t_m_finie       .text "PARTIE FINIE - N = REJOUER"
                .byte 0
t_m_niveau      .text "NIVEAU : TAPEZ 1 "
                .byte ACC_A_GRAVE
                .text " 6"
                .byte 0

; ---------------------------------------------------------------------
;  Table des textes fixes du panneau
;  Format : ligne, colonne, attribut, adresse (poids faible, poids fort)
;  Fin de table : $FF
; ---------------------------------------------------------------------
textes_fixes
        .byte LIG_TITRE, PAN_X+4, INVERSE
        .word t_titre
        .byte LIG_TITRE, PAN_X+17, INVERSE
        .word t_machine

        .byte LIG_TRAIT,   PAN_T, 0
        .word t_trait
        .byte LIG_ORDI,    PAN_T, 0
        .word t_ordi
        .byte LIG_NIVEAU,  PAN_T, 0
        .word t_niveau
        .byte LIG_PENDULE, PAN_T, 0
        .word t_pendule

        .byte LIG_H_PARTIE,  PAN_T+10, INVERSE
        .word t_h_partie
        .byte LIG_H_PRISES,  PAN_T+7,  INVERSE
        .word t_h_prises
        .byte LIG_H_LEGENDE, PAN_T+10, INVERSE
        .word t_h_legende

        .byte LIG_LEGENDE,   PAN_T, 0
        .word t_leg1
        .byte LIG_LEGENDE+1, PAN_T, 0
        .word t_leg2
        .byte LIG_LEGENDE+2, PAN_T, 0
        .word t_leg3
        .byte LIG_LEGENDE+3, PAN_T, 0
        .word t_leg4
        .byte LIG_LEGENDE+4, PAN_T, 0
        .word t_leg5

        .byte LIG_TOUCHES, PAN_T, 0
        .word t_touches
        .byte $FF

; ---------------------------------------------------------------------
;  Ecran de choix du jeu de caracteres
;  Lettres sans accent uniquement : il faut pouvoir lire cet ecran avant
;  d'avoir choisi la ROM.
; ---------------------------------------------------------------------
t_rom_standard  .text "1 - STANDARD"
                .byte 0
t_rom_edex      .text "2 - EDEX"
                .byte 0
t_rom_lettres   .text "3 - LETTRES"
                .byte 0
t_rom_question  .text "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"
                .byte 0
t_rom_indice    .text "RETENEZ L'ECHANTILLON OU LES PIECES SONT LISIBLES"
                .byte 0
t_rom_indice3   .text "1 POUR LA ROM D'ORIGINE, 2 POUR L'EPROM FRANCAISE AZ-E-01."
                .byte 0
t_rom_indice4   .text "3 DONNE LA LETTRE DE LA PIECE, SI LES DEUX AUTRES ECHOUENT."
                .byte 0
t_rom_touches   .text "1, 2 OU 3 POUR CHOISIR      RETURN POUR VALIDER"
                .byte 0

rom_textes
        .byte LIG_TITRE, 33, INVERSE
        .word t_titre
        .byte 3, 20, 0
        .word t_rom_question
        .byte 16, 15, 0
        .word t_rom_indice
        .byte 19, 10, 0
        .word t_rom_indice3
        .byte 20, 10, 0
        .word t_rom_indice4
        .byte 22, 16, 0
        .word t_rom_touches
        .byte $FF

; Les trois choix : colonne de l'echantillon, libelle, prereglage
rom_lignes
        .byte ROM_L_TITRE, ROM_L_TITRE, ROM_L_TITRE
rom_colonnes
        .byte ROM_COL_1, ROM_COL_2, ROM_COL_3
rom_libelles_lo
        .byte <t_rom_standard, <t_rom_edex, <t_rom_lettres
rom_libelles_hi
        .byte >t_rom_standard, >t_rom_edex, >t_rom_lettres
prereglages_lo
        .byte <rom_standard, <rom_edex, <rom_lettres
prereglages_hi
        .byte >rom_standard, >rom_edex, >rom_lettres

; Cases de l'echantillon : ligne, colonne, fond (1 = claire), piece
ech_defs
        .byte 0, 0, 1, CAVALIER|BLANC
        .byte 0, 6, 0, ROI|BLANC
        .byte 3, 0, 0, CAVALIER|NOIR
        .byte 3, 6, 1, ROI|NOIR
        .byte $FF

; ---------------------------------------------------------------------
;  Empreintes des ROM d'editeur standard connues (somme 16 bits de
;  $E000-$E7FF). Les versions 50 Hz et 60 Hz donnent la meme ; VICE
;  charge une variante qui en donne une autre.
; ---------------------------------------------------------------------
empreintes_lo
        .byte <$528A, <$52AE
empreintes_hi
        .byte >$528A, >$52AE
NB_EMPREINTES = * - empreintes_hi

; ---------------------------------------------------------------------
;  Prereglages des formes dependantes de la ROM de caracteres.
;  L'ordre suit exactement celui des variables, de car_quarts a
;  pieces_graphiques : appliquer_rom se contente d'une recopie.
;
;  ROM standard : celle de VICE et des 8296 non francises. Les codes des
;  seize quarts de bloc ont ete releves dans le generateur de caracteres
;  (outils/verifier_quarts.py).
;
;  ROM francaise (EPROM AZ-E-01 du proprietaire) : en mode graphique elle
;  remplace les codes 97 a 127 par des cadres et des minuscules
;  accentuees, et n'a donc PAS les quarts de bloc. Les pieces y passent
;  par le repli "lettre encadree" (pieces_graphiques = 0) et les cases
;  claires par un pointille.
;
;  TODO (question ouverte de CLAUDE.md) : verifier si l'autre jeu de cette
;  EPROM (mode texte #14) porte les quarts de bloc. Le proprietaire
;  photographie la table des 256 codes. Si oui, il suffira de remplir ici
;  les seize codes et de remettre pieces_graphiques a 1.
; ---------------------------------------------------------------------
rom_standard
        ; les seize quarts, du masque 0 au masque 15
        .byte  32,126,124,226,123, 97,255,236
        .byte 108,127,225,251, 98,252,254,160
        .byte 102                       ; damier des cases claires
        .byte $55, $49, $4A, $4B        ; arcs du cadre : HG HD BG BD
        .byte $40, $5D                  ; traits horizontal et vertical
        .byte 5, 5, 1, 21, 3            ; accents : lettres sans accent
        .byte 1                         ; pieces dessinees
        .word pieces_blanches, pieces_noires

; ---------------------------------------------------------------------
;  EPROM francaise : les pieces y sont dessinees avec les formes dont
;  elle dispose en mode graphique -- quatre triangles d'angle et le bloc
;  plein -- au lieu des quarts de bloc, qu'elle n'a pas. Les codes ont
;  ete releves sur la vraie 8296. Cases claires en pointille.
; ---------------------------------------------------------------------
rom_edex
        ; les quarts n'existent pas ici : place tenue, jamais lue, les
        ; pieces venant de leur propre table
        .byte  32,126,124,226,123, 97,255,236
        .byte 108,127,225,251, 98,252,254,160
        .byte 46                        ; pointille des cases claires
        .byte 82, 84, 70, 71            ; arcs du cadre : HG HD BG BD
        .byte 102, 97                   ; traits horizontal et vertical
        .byte 127, 114, 113, 117, 3     ; e aigu, e grave, a grave, u grave,
                                        ; et C faute de cedille
        .byte 1                         ; pieces dessinees
        .word pieces_edex_blanches, pieces_edex_noires

; ---------------------------------------------------------------------
;  Repli : chaque piece est sa lettre francaise dans un cadre arrondi.
;  Il ne demande que des traits et des coins, que toute ROM possede ;
;  c'est le choix de secours si les deux autres ne donnent rien.
; ---------------------------------------------------------------------
rom_lettres
        .byte  32,126,124,226,123, 97,255,236
        .byte 108,127,225,251, 98,252,254,160
        .byte 46                        ; pointille des cases claires
        .byte 82, 84, 70, 71            ; arcs du cadre : HG HD BG BD
        .byte 102, 97                   ; traits horizontal et vertical
        .byte 127, 114, 113, 117, 3
        .byte 0                         ; repli "lettre encadree"
        .word pieces_blanches, pieces_noires     ; non lues

; ---------------------------------------------------------------------
;  Lettres francaises des pieces, indexees par le type (1..6)
; ---------------------------------------------------------------------
lettres_pieces  .text "PCFTDR"

; ---------------------------------------------------------------------
;  Rangee de depart des Blancs, colonne A a H
; ---------------------------------------------------------------------
rangee_depart
        .byte TOUR, CAVALIER, FOU, DAME, ROI, FOU, CAVALIER, TOUR

; ---------------------------------------------------------------------
;  Ecran d'aide : liste des touches
; ---------------------------------------------------------------------
t_aide_titre    .text "AIDE - LES TOUCHES DU JEU"
                .byte 0
t_aide1         .text "FLECHES / PAVE 8 2 4 6   DEPLACER LE CURSEUR"
                .byte 0
t_aide2         .text "PAVE 7 9 1 3             DEPLACER EN DIAGONALE"
                .byte 0
t_aide3         .text "RETURN OU ESPACE         CHOISIR, PUIS JOUER"
                .byte 0
t_aide4         .text "LETTRE OU CHIFFRE        SAISIE EN NOTATION"
                .byte 0
t_aide5         .text "                         PAR EXEMPLE E2-E4"
                .byte 0
t_aide6         .text "DEL                      EFFACER LA SAISIE"
                .byte 0
t_aide7         .text "U                        ANNULER SON COUP ET LA REPONSE"
                .byte 0
t_aide8         .text "L                        CHANGER DE NIVEAU"
                .byte 0
t_aide9         .text "O                        ROQUE (O-O OU O-O-O)"
                .byte 0
t_aide10        .text "N                        NOUVELLE PARTIE"
                .byte 0
t_aide11        .text "M                        REVOIR LE CHOIX DE ROM"
                .byte 0
t_aide12        .text "Q                        QUITTER"
                .byte 0
t_aide13        .text "J                        CAMP TENU PAR L'ORDINATEUR"
                .byte 0
t_aide14        .text "STOP                     FAIRE JOUER L'ORDINATEUR"
                .byte 0
t_aide_fin      .text "UNE TOUCHE POUR REVENIR A LA PARTIE"
                .byte 0

aide_textes
        .byte LIG_TITRE, 27, INVERSE
        .word t_aide_titre
        .byte  4, 10, 0
        .word t_aide1
        .byte  5, 10, 0
        .word t_aide2
        .byte  7, 10, 0
        .word t_aide3
        .byte  8, 10, 0
        .word t_aide4
        .byte  9, 10, 0
        .word t_aide5
        .byte 10, 10, 0
        .word t_aide6
        .byte 12, 10, 0
        .word t_aide7
        .byte 13, 10, 0
        .word t_aide8
        .byte 14, 10, 0
        .word t_aide9
        .byte 15, 10, 0
        .word t_aide10
        .byte 16, 10, 0
        .word t_aide11
        .byte 17, 10, 0
        .word t_aide12
        .byte 19, 10, 0
        .word t_aide13
        .byte 20, 10, 0
        .word t_aide14
        .byte 22, 22, INVERSE
        .word t_aide_fin
        .byte $FF

; ---------------------------------------------------------------------
;  Touches de deplacement du curseur et direction correspondante.
;  Il suffit d'ajouter une ligne ici pour reconnaitre un code de plus, par
;  exemple si l'editeur EDEX donne au pave numerique des codes propres.
; ---------------------------------------------------------------------
nav_touches
        .byte T_GAUCHE, T_DROITE, T_HAUT, T_BAS
        .byte T_PAV_GAUCHE, T_PAV_DROITE, T_PAV_HAUT, T_PAV_BAS
        .byte T_PAV_HG, T_PAV_HD, T_PAV_BG, T_PAV_BD
NAV_NOMBRE = * - nav_touches

nav_directions
        .byte DIR_GAUCHE, DIR_DROITE, DIR_HAUT, DIR_BAS
        .byte DIR_GAUCHE, DIR_DROITE, DIR_HAUT, DIR_BAS
        .byte DIR_HG, DIR_HD, DIR_BG, DIR_BD

; Decalage dans le plateau pour chacune des huit directions
dir_decalage
        .byte DEP_GAUCHE, DEP_DROITE, DEP_HAUT, DEP_BAS
        .byte DEP_HG, DEP_HD, DEP_BG, DEP_BD

.enc "none"

; =====================================================================
;  Variables en RAM
; =====================================================================

; --- formes dependantes de la ROM, remplies par appliquer_rom ---------
;     Elles se suivent dans l'ordre des prereglages : ne pas intercaler.
car_quarts      .fill NB_QUARTS, 0
car_damier      .byte 0
car_arc_hg      .byte 0
car_arc_hd      .byte 0
car_arc_bg      .byte 0
car_arc_bd      .byte 0
car_trait_h     .byte 0
car_trait_v     .byte 0
accents         .fill NB_ACCENTS, 0
pieces_graphiques .byte 1       ; 1 = pieces dessinees (tables ci-dessous),
                                ; 0 = repli "lettre encadree"
ptr_pieces_b    .byte 0, 0      ; table des pieces blanches du prereglage
ptr_pieces_n    .byte 0, 0      ; et celle des noires
; --- fin des variables recopiees depuis le prereglage ---
rom_choisie     .byte 1         ; 0 = standard, 1 = EDEX, 2 = lettres
som_lo          .byte 0         ; somme de controle de la ROM editeur
som_hi          .byte 0

; --- variables de travail de l'affichage -----------------------------
tmp_ligne       .byte 0
tmp_colonne     .byte 0
tmp_rangee      .byte 0
tmp_car         .byte 0
tmp_car_op      .byte 0         ; caractere tranchant sur tmp_car (marquages)
tmp_index       .byte 0
attr_texte      .byte 0
attr_case       .byte 0         ; $80 quand toute la case est inversee
attr_piece      .byte 0
case_courante   .byte 0
piece_courante  .byte 0
ech_colonne     .byte 0
sauve_y         .byte 0
v_dizaine       .byte 0
v_unite         .byte 0

; --- etat de la partie, tables et variables des regles ---------------
;     Dans un fichier a part : perft.asm les reprend sans l'affichage.
        .include "donnees_regles.asm"

; --- pendule ---------------------------------------------------------
pend_prec       .byte 0, 0      ; valeur de TI au dernier passage
pend_acc        .byte 0, 0      ; jiffies accumules
pend_sec        .byte 0
pend_min        .byte 0

; --- saisie en notation ----------------------------------------------
SAISIE_MAX      = 7
mode_saisie     .byte 0
saisie          .fill SAISIE_MAX, 0
nb_saisie       .byte 0
col_curseur     .byte 0
attente_conf    .byte 0         ; 1 = nouvelle partie, 2 = quitter,
                                ; 3 = choix du niveau
attente_promo   .byte 0         ; 1 = on attend la piece de promotion
promo_lettres   .byte $43, $46, $54, $44     ; C F T D, dans l'ordre de
                                ; promo_types ; la dame est en dernier
sa_index        .byte 0         ; variables de l'analyse de la saisie
sa_depart       .byte 0
sa_arrivee      .byte 0

; --- notation des derniers coups -------------------------------------
NOTE_LG         = 6             ; "CG1-F3"
NOTE_NB         = 8             ; quatre par ligne, sur deux lignes
notation        .fill NOTE_LG*NOTE_NB, CAR_ESPACE
nb_notes        .byte 0

; --- coups legaux de la position affichee -----------------------------
nb_coups_partie .byte 0
nb_variantes    .byte 0         ; coups allant du meme depart a la meme
                                ; arrivee : 4 pour une promotion
ed_case         .byte 0
sel_prec        .byte 0         ; case choisie dont on redessine le tour
sauve_x         .byte 0
mi_compte       .byte 0, 0      ; pieces mineures de chaque camp
mi_fous_b       .byte 0         ; bit 1 : un fou ; bit 0 : sur case foncee
mi_fous_n       .byte 0
mi_tmp          .byte 0
tr_vues         .byte 0         ; occurrences deja rencontrees
tr_recul        .byte 0
tr_max          .byte 0         ; demi-coups a remonter, fige au depart
roque_ref       .byte 0
ep_ref          .byte 0

; --- pieces prises ---------------------------------------------------
PRISES_MAX      = 28
prises          .fill PRISES_MAX, 0
nb_prises       .byte 0

; --- sauvegarde de la page zero empruntee ----------------------------
sauvegarde_pz   .fill PZ_NOMBRE, 0
