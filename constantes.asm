; =====================================================================
;  constantes.asm - adresses materielles, codes ecran, geometrie
;  Jeu d'echecs pour Commodore 8296
; =====================================================================

; ---------------------------------------------------------------------
;  Materiel Commodore 8296
; ---------------------------------------------------------------------
ECRAN       = $8000         ; memoire ecran, 80 colonnes x 25 lignes
LARGEUR     = 80
HAUTEUR     = 25

REG_CARACT  = $E84C         ; VIA PCR : pilote le jeu de caracteres
                            ; (equivalent assembleur de POKE 59468,n)
MODE_GRAPH  = 12            ; majuscules + graphiques (mode du jeu)
MODE_MINUS  = 14            ; minuscules / majuscules

GETIN       = $FFE4         ; KERNAL : lit un caractere clavier (0 = rien)
CHROUT      = $FFD2         ; KERNAL : ecrit un caractere via l'editeur
PET_EFFACER = $93           ; code PETSCII d'effacement de l'ecran

; Horloge systeme TI : trois octets, poids fort en premier. On n'utilise
; que les deux de poids faible, qui bouclent en 21 minutes : largement
; assez pour mesurer un intervalle entre deux passages.
TI_MOYEN    = $008E
TI_BAS      = $008F
JIFFY_LO    = $008F

; Registre de commutation de la RAM etendue (ecriture seule). Reserve a
; l'etape 3 (table de transpositions, bibliotheque d'ouvertures) ; tant
; que son effet n'est pas verifie sur la vraie machine on n'y touche pas.
REG_RAM_ETENDUE = $FFF0

; ---------------------------------------------------------------------
;  Page zero utilisee par le jeu
;
;  Le programme ne rend pas la main au BASIC pendant la partie, mais l'IRQ
;  du KERNAL (horloge, clavier, curseur) continue de tourner. Zone retenue :
;  $B0..$C3, la zone de travail de la cassette. Mesure faite dans VICE pour
;  le jeu de dames : en laissant tourner les interruptions plusieurs
;  secondes, $B0..$CA restent intacts, tandis que $F8..$FA sont modifies
;  par le systeme (table des lignes ecran de l'editeur).
;  La zone est tout de meme sauvegardee au demarrage et rendue a la sortie.
;
;  TODO machine reelle : l'EPROM EDEX 8000 est un editeur modifie ;
;  verifier qu'apres une partie, LOAD et SAVE cassette fonctionnent encore.
; ---------------------------------------------------------------------
PZ_BASE     = $B0
PZ_NOMBRE   = 20            ; $B0..$C3

; Seuls les pointeurs ont besoin de la page zero, pour l'adressage
; indirect indexe ; les octets simplement temporaires sont en RAM
; ordinaire (pz_tmp et compagnie, dans donnees_regles.asm).
;
; Ne pas deborder au-dela de $C3 : $C4 a $C6 appartiennent a l'editeur
; d'ecran du KERNAL (pointeur de ligne et colonne du curseur). Les y
; ecraser ne derange pas le jeu, qui ecrit lui-meme dans la memoire
; ecran, mais casse CHROUT -- donc l'affichage de perft.prg et de
; test_ia.prg, et le "ready." du retour au BASIC.
ptr_ecran   = $B0           ; $B0/$B1 pointeur de travail vers l'ecran
ptr_texte   = $B2           ; $B2/$B3 pointeur vers une chaine
ptr_aux     = $B4           ; $B4/$B5 pointeur auxiliaire
ptr_eval    = $B6           ; $B6/$B7 table de position de l'evaluation
ptr_piece   = $B8           ; $B8/$B9 les 12 codes de la piece a dessiner
coups_fin   = $BA           ; $BA/$BB ou ranger le prochain coup genere
ptr_coup    = $BC           ; $BC/$BD coup en cours d'examen
ptr_hist    = $BE           ; $BE/$BF sommet de l'historique de la partie
ptr_ecrit   = $C0           ; $C0/$C1 ou recopier un coup garde
pz_tmp3     = $C2           ; octets temporaires de l'affichage
pz_tmp4     = $C3

; ---------------------------------------------------------------------
;  Codes ecran PETSCII, mode majuscules + graphiques
;  Ajouter INVERSE ($80) pour la video inverse.
; ---------------------------------------------------------------------
INVERSE     = $80

CAR_ESPACE  = $20           ; espace
CAR_ESP_INV = $A0           ; espace inverse (bloc plein)
CAR_ZERO    = $30           ; code ecran du chiffre 0
CAR_A       = $01           ; code ecran de la lettre A
CAR_P       = $10           ; code ecran de la lettre P
CAR_TIRET   = $2D           ; trait d'union, pour la notation E2-E4
CAR_PRISE   = $18           ; X, separateur des prises : FF1XB5
CAR_DEUXPTS = $3A           ; deux-points de la pendule

; Formes dependantes de la ROM de caracteres : elles sont lues dans des
; variables (car_*), remplies au demarrage par appliquer_rom depuis l'un
; des deux prereglages de donnees.asm.
NB_QUARTS   = 16            ; les 16 combinaisons de quarts de bloc
NB_CAR_ROM  = 7             ; damier, 4 arcs, 2 traits
NB_ACCENTS  = 5             ; e aigu, e grave, a grave, u grave, c cedille
NB_CAR_TOTAL = NB_QUARTS + NB_CAR_ROM + NB_ACCENTS + 5  ; + pieces_graphiques
                                                        ; + deux adresses
                                                        ;   de tables
NB_ROMS     = 3             ; prereglages proposes au demarrage

; Marqueurs d'accent dans les textes. Ils occupent des codes que le jeu
; n'emploie pas ailleurs ($1B a $1F) ; afficher_texte les remplace par le
; caractere de la ROM active, ou par la lettre sans accent.
ACC_E_AIGU  = $1B
ACC_E_GRAVE = $1C
ACC_A_GRAVE = $1D
ACC_U_GRAVE = $1E
ACC_C_CEDIL = $1F

; ---------------------------------------------------------------------
;  Geometrie de l'ecran (disposition validee sur maquette)
;
;  Les caracteres du moniteur sont environ 2,4 fois plus hauts que larges :
;  une case de 6 x 3 caracteres parait a peu pres carree. L'echiquier
;  occupe toute la hauteur de l'ecran.
;
;  case (rangee r = 0..7 depuis le haut, colonne c = 0..7)
;      x0 = COL_ECH + 6*c    (colonnes 2..49)
;      y0 = 3*r              (lignes 0..23)
;  La rangee 8 (les Noirs) est en haut, la rangee 1 (les Blancs) en bas.
; ---------------------------------------------------------------------
COL_ECH     = 2             ; premiere colonne de l'echiquier
CASE_L      = 6             ; largeur d'une case en caracteres
CASE_H      = 3             ; hauteur d'une case en caracteres

COL_COORD   = 0             ; colonne des chiffres 8..1
LIG_LETTRES = 24            ; ligne des lettres A..H
DEC_LETTRE  = 3             ; la lettre se pose en x0 + 3

PIECE_DX    = 1             ; la piece occupe les colonnes 1..4 de la case
LETTRE_DX   = 1             ; le cadre "lettre encadree" les colonnes 1..3

; ---------------------------------------------------------------------
;  Panneau d'informations : colonnes 51 a 79
;  Les en-tetes sont en video inverse sur toute la largeur du panneau,
;  le texte courant commence une colonne plus loin.
; ---------------------------------------------------------------------
PAN_X       = 51            ; premiere colonne du panneau
PAN_L       = 29            ; largeur du panneau (colonnes 51..79)
PAN_T       = 52            ; premiere colonne du texte courant
PAN_LT      = 28            ; largeur utile du texte

LIG_TITRE   = 0
LIG_TRAIT   = 2
LIG_ORDI    = 3
LIG_NIVEAU  = 4
LIG_PENDULE = 5
LIG_H_PARTIE = 7            ; en-tete "PARTIE"
LIG_COUPS   = 8             ; deux lignes de derniers coups
LIG_H_PRISES = 10           ; en-tete "PIECES PRISES"
LIG_PRISES  = 11
LIG_H_LEGENDE = 13          ; en-tete "LEGENDE"
LIG_LEGENDE = 14            ; cinq lignes de legende
LIG_MSG     = 20            ; deux lignes de message
LIG_SAISIE  = 22            ; "VOTRE COUP : ..."
LIG_CURSEUR = 23            ; case pointee par le curseur
LIG_TOUCHES = 24            ; rappel des touches

COL_VALEUR  = PAN_T+9       ; colonne des valeurs de TRAIT / ORDI / NIVEAU

; ---------------------------------------------------------------------
;  Contenu d'une case du plateau
;  Le type tient sur les bits 0 a 2, la couleur sur le bit 3 : tester la
;  couleur d'une piece est un AND #NOIR, son type un AND #MASQUE_TYPE.
; ---------------------------------------------------------------------
VIDE        = 0
PION        = 1
CAVALIER    = 2
FOU         = 3
TOUR        = 4
DAME        = 5
ROI         = 6
MASQUE_TYPE = 7

BLANC       = 0             ; valeurs de la variable "trait"
NOIR        = 8             ; et bit de couleur d'une piece
MASQUE_COUL = 8

PION_B      = PION|BLANC
PION_N      = PION|NOIR
ROI_B       = ROI|BLANC
ROI_N       = ROI|NOIR

ORDI_AUCUN  = $FF           ; camp_ordi : les deux camps sont tenus par
                            ; des joueurs ; sinon BLANC ou NOIR

; ---------------------------------------------------------------------
;  Plateau 0x88 : index = 16 * rangee + colonne, rangee 0 = rangee 1 des
;  Blancs. Une case est hors echiquier si et seulement si index AND $88
;  n'est pas nul.
; ---------------------------------------------------------------------
HORS_ECH    = $88           ; masque du test de bord

DEP_DROITE  = 1             ; decalages des huit directions
DEP_GAUCHE  = $FF           ; -1
DEP_HAUT    = 16            ; vers la rangee 8, donc vers le haut de l'ecran
DEP_BAS     = $F0           ; -16
DEP_HG      = 15            ; haut-gauche
DEP_HD      = 17
DEP_BG      = $EF           ; -17
DEP_BD      = $F1           ; -15

CASE_DEPART = $14           ; E2, position de depart du curseur

CASE_E1     = $04           ; cases qui comptent pour le roque
CASE_A1     = $00
CASE_H1     = $07
CASE_B1     = $01
CASE_C1     = $02
CASE_D1     = $03
CASE_F1     = $05
CASE_G1     = $06
RANGEE_8    = $70           ; a ajouter pour passer aux cases noires

RANG_2_B    = $10           ; rangee du double pas des pions blancs
RANG_2_N    = $60
RANG_PROMO_B = $70          ; rangee de promotion
RANG_PROMO_N = $00

AUCUNE_CASE = $FF           ; case_ep quand aucune prise en passant

; ---------------------------------------------------------------------
;  Un coup tient sur quatre octets : depart, arrivee, drapeau, score.
;  Le score ne sert qu'au tri de la recherche (etape 3).
; ---------------------------------------------------------------------
COUP_OCTETS = 4

CP_NORMAL   = 0
CP_DOUBLE   = 1             ; double pas d'un pion : ouvre la prise en passant
CP_EP       = 2             ; prise en passant
CP_PETIT    = 3             ; petit roque (le roi va en colonne G)
CP_GRAND    = 4             ; grand roque (colonne C)
CP_PROMO    = 8             ; CP_PROMO + type de la piece promue

; Droits de roque restants, un bit par roque
ROQUE_BP    = 1             ; Blancs, petit roque
ROQUE_BG    = 2             ; Blancs, grand roque
ROQUE_NP    = 4
ROQUE_NG    = 8
ROQUE_TOUS  = ROQUE_BP|ROQUE_BG|ROQUE_NP|ROQUE_NG

; Les directions, dans l'ordre de la table dir_toutes :
;   0..3 orthogonales (droite, gauche, haut, bas)
;   4..7 diagonales   (HD, HG, BD, BG)
;   8..15 sauts du cavalier
DIR_ORTHO   = 0
DIR_DIAG    = 4
DIR_CAVAL   = 8
DIR_DERN    = 15

PROF_MAX    = 24            ; profondeur maximale de recursion

; ---------------------------------------------------------------------
;  Codes PETSCII renvoyes par GETIN
;
;  Les fleches du clavier "business" du 8296 sont deux touches CRSR : haut
;  et gauche s'obtiennent avec SHIFT. Le pave numerique occupe des
;  positions distinctes dans la matrice, mais l'editeur le decode tres
;  probablement vers les memes codes que les chiffres de la rangee du haut.
;
;  TODO machine reelle : verifier ces codes, l'editeur EDEX pouvant en
;  renvoyer d'autres. Il suffira alors de completer la table nav_touches
;  de donnees.asm.
; ---------------------------------------------------------------------
T_DROITE    = $1D
T_GAUCHE    = $9D
T_BAS       = $11
T_HAUT      = $91

T_PAV_HG    = $37           ; 7
T_PAV_HAUT  = $38           ; 8
T_PAV_HD    = $39           ; 9
T_PAV_GAUCHE = $34          ; 4
T_PAV_DROITE = $36          ; 6
T_PAV_BG    = $31           ; 1
T_PAV_BAS   = $32           ; 2
T_PAV_BD    = $33           ; 3

TOUCHE_RET  = $0D           ; RETURN : valide
TOUCHE_ESP  = $20           ; ESPACE : valide aussi
TOUCHE_DEL  = $14           ; DEL : efface un caractere en saisie
TOUCHE_STOP = $03           ; STOP : interrompt la reflexion
TOUCHE_AIDE = $3F           ; ?
TOUCHE_U    = $55           ; U = annuler le dernier coup
TOUCHE_N    = $4E           ; N = nouvelle partie
TOUCHE_Q    = $51           ; Q = quitter
TOUCHE_L    = $4C           ; L = changer de niveau
TOUCHE_J    = $4A           ; J = camp tenu par l'ordinateur
TOUCHE_M    = $4D           ; M = retour au menu
TOUCHE_O    = $4F           ; O = debut de la saisie du roque
TOUCHE_OUI  = $4F           ; O de "oui" (confirmations)

; Directions, dans l'ordre utilise par nav_directions
DIR_GAUCHE  = 0
DIR_DROITE  = 1
DIR_HAUT    = 2
DIR_BAS     = 3
DIR_HG      = 4
DIR_HD      = 5
DIR_BG      = 6
DIR_BD      = 7

; ---------------------------------------------------------------------
;  Niveaux de jeu
; ---------------------------------------------------------------------
NB_NIVEAUX  = 6

; ---------------------------------------------------------------------
;  Zones de travail, a adresse fixe au-dela du programme. Elles ne sont
;  pas dans le .prg (ce serait des kilo-octets de remplissage) et sont
;  mises a zero au demarrage. main.asm verifie a l'assemblage que le
;  programme ne les rattrape pas : une collision silencieuse abime le
;  plateau en pleine recherche, et c'est fort desagreable a diagnostiquer.
; ---------------------------------------------------------------------
DEBUT_ZONES = $5000

; Pile des coups joues, qui sert a la fois au retour en arriere du
; joueur et au make / unmake de la recherche : celle-ci empile par-dessus
; la partie et depile toujours ce qu'elle a empile. Huit octets par
; demi-coup : depart, arrivee, piece deplacee, piece prise, droits de
; roque, case de prise en passant, compteur des 50 coups, drapeau.
HIST_OCTETS = 8
HIST_MAX    = 384           ; demi-coups de partie gardes (CLAUDE.md en
                            ; demande 300) ; au-dela, le plus ancien est
                            ; oublie par glisser_hist
HIST_PAGES  = HIST_OCTETS*HIST_MAX/256      ; 12 pages pleines
HIST_PILE   = 512           ; entrees reservees : la partie, plus la
                            ; marge ou la recherche empile
hist_zone   = $5000
HIST_FIN    = hist_zone + HIST_OCTETS*HIST_PILE  ; $6000

; Listes de coups : la premiere tranche garde les coups legaux de la
; position affichee (218 au plus, soit 872 octets), le reste sert aux
; tranches de la recherche, une par demi-coup explore.
coups_zone  = $6000
TAILLE_COUPS = $1C00        ; 7 Ko, $6000..$7BFF
LISTE_PARTIE = coups_zone
RECHERCHE_ZONE = coups_zone + $400

; Copie de travail du plateau, pour la detection de triple repetition.
plateau_ref = $7C00

; ---------------------------------------------------------------------
;  Variables de la recherche, une entree par niveau de recursion. Elles
;  sont en zone fixe plutot que dans le .prg : ce ne sont que des cases
;  de travail, et le programme n'a pas a les transporter.
; ---------------------------------------------------------------------
rech_zone     = $7C80
rc_t_prof     = rech_zone
rc_t_alpha_lo = rech_zone + PROF_MAX
rc_t_alpha_hi = rech_zone + PROF_MAX*2
rc_t_beta_lo  = rech_zone + PROF_MAX*3
rc_t_beta_hi  = rech_zone + PROF_MAX*4
rc_t_deb_lo   = rech_zone + PROF_MAX*5
rc_t_deb_hi   = rech_zone + PROF_MAX*6
rc_t_fin_lo   = rech_zone + PROF_MAX*7
rc_t_fin_hi   = rech_zone + PROF_MAX*8
rc_t_coup     = rech_zone + PROF_MAX*9
RECH_FIN      = rech_zone + PROF_MAX*10

; ---------------------------------------------------------------------
;  Evaluation et recherche
; ---------------------------------------------------------------------
; Un mat vaut plus que n'importe quel avantage materiel ; on lui retire
; le nombre de demi-coups qui y menent, pour que le programme choisisse
; le mat le plus court et recule le plus possible celui qu'il subit.
MAT_SCORE   = 30000
MAT_SEUIL   = 29000         ; au-dela, le score annonce un mat

SEUIL_FINALE = 1300         ; matiere hors pions des deux camps en dessous
                            ; de laquelle le roi doit sortir de son abri
MALUS_DOUBLE = 12           ; par pion double, en centipions
MALUS_ISOLE  = 18

COUP_PRIS   = $FF           ; note d'un coup deja essaye dans la tranche
TOUCHES_MAX = 8             ; touches gardees pendant la reflexion
                            ; (une puissance de deux : l'index boucle
                            ; par un simple AND)
PROF_QUIET  = 14            ; niveau au-dela duquel la recherche de calme
                            ; s'arrete, pour ne pas vider la pile du 6502

; ---------------------------------------------------------------------
;  Fins de partie, valeurs de partie_finie
; ---------------------------------------------------------------------
FIN_RIEN    = 0
FIN_MAT     = 1
FIN_PAT     = 2
FIN_50      = 3
FIN_MATERIEL = 4
FIN_REPETITION = 5
