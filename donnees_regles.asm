; =====================================================================
;  donnees_regles.asm - etat de la partie, tables et variables des regles
;
;  Ce fichier est inclus par donnees.asm (le jeu complet) et directement
;  par perft.asm (le programme de validation du generateur de coups), qui
;  n'a besoin ni de l'affichage ni du clavier.
; =====================================================================

; ---------------------------------------------------------------------
;  Tables de directions, en index 0x88
;
;  Les quatre premieres sont orthogonales, les quatre suivantes
;  diagonales, les huit dernieres sont les sauts du cavalier. L'ordre
;  compte : est_attaquee et le generateur s'en servent pour distinguer
;  une tour d'un fou, et pour savoir de quel cote un pion prend.
; ---------------------------------------------------------------------
dir_toutes
        .byte DEP_DROITE, DEP_GAUCHE, DEP_HAUT, DEP_BAS
        .byte DEP_HD, DEP_HG, DEP_BD, DEP_BG
        .byte 33, 31, 18, 14, $F2, $EE, $E1, $DF

; Premiere et derniere direction a suivre, par type de piece. Seuls le
; fou, la tour et la dame glissent ; le roi reprend les huit directions
; mais d'un seul pas.
;        VIDE PION CAV FOU TOUR DAME ROI
dir_deb .byte 0,   0,  0,  4,  0,   0,   0
dir_fin .byte 0,   0,  0,  7,  3,   7,   7

; Cases dont le passage retire un droit de roque, et masque a appliquer.
roque_cases
        .byte CASE_E1, CASE_A1, CASE_H1
        .byte CASE_E1+RANGEE_8, CASE_A1+RANGEE_8, CASE_H1+RANGEE_8
roque_masques
        .byte ROQUE_TOUS&~(ROQUE_BP|ROQUE_BG)
        .byte ROQUE_TOUS&~ROQUE_BG
        .byte ROQUE_TOUS&~ROQUE_BP
        .byte ROQUE_TOUS&~(ROQUE_NP|ROQUE_NG)
        .byte ROQUE_TOUS&~ROQUE_NG
        .byte ROQUE_TOUS&~ROQUE_NP

; Pieces proposees a la promotion, de la moins forte a la plus forte :
; la dame est ajoutee en dernier, donc en tete des coups les mieux notes
; une fois la liste triee.
promo_types
        .byte CAVALIER, FOU, TOUR, DAME

; ---------------------------------------------------------------------
;  Etat de la partie
; ---------------------------------------------------------------------
plateau         .fill 128, VIDE
trait           .byte BLANC     ; camp au trait
droits_roque    .byte ROQUE_TOUS
case_ep         .byte AUCUNE_CASE   ; case traversee par un double pas
demi_50         .byte 0         ; demi-coups depuis la derniere prise ou
                                ; le dernier coup de pion
pos_roi         .byte CASE_E1, CASE_E1+RANGEE_8   ; index par couleur
curseur         .byte CASE_DEPART
selection       .byte $FF       ; case choisie, $FF si aucune
niveau          .byte 3
camp_ordi       .byte ORDI_AUCUN
demande_fin     .byte 0
retour_menu     .byte 0
partie_finie    .byte 0
clign_phase     .byte 0
nb_demi_coups   .byte 0         ; demi-coups joues, pour le retour arriere
nb_demi_hi      .byte 0

; --- coup en cours de jeu --------------------------------------------
cp_depart       .byte 0
cp_arrivee      .byte 0
cp_piece        .byte 0
cp_prise        .byte 0
cp_drapeau      .byte 0
ji_tmp          .byte 0         ; pour les coups a deux temps
pz_tmp          .byte 0         ; octets temporaires : la page zero est
pz_tmp2         .byte 0         ; reservee aux pointeurs
ptr_liste       .byte 0, 0      ; debut de la tranche de coups du niveau
                                ; (jamais lu en indirect : la RAM suffit)

; --- generation des coups --------------------------------------------
gc_depart       .byte 0
gc_arrivee      .byte 0
gc_piece        .byte 0
gc_drapeau      .byte 0
gc_dir          .byte 0
gc_dfin         .byte 0
gc_pas          .byte 0
gc_rang2        .byte 0         ; rangee du double pas du camp au trait
gc_rangp        .byte 0         ; rangee de promotion
gc_nb           .byte 0         ; coups produits par le dernier appel

; --- recherche d'attaque ---------------------------------------------
ea_case         .byte 0
ea_camp         .byte 0
ea_piece        .byte 0
ea_pas          .byte 0

; --- recursion (perft, puis recherche) -------------------------------
pf_prof         .byte 0         ; profondeur restante
pf_niv          .byte 0         ; niveau de recursion courant
pf_nb           .byte 0, 0, 0, 0    ; compteur de feuilles, 32 bits
pf_deb_lo       .fill PROF_MAX, 0
pf_deb_hi       .fill PROF_MAX, 0
pf_cur_lo       .fill PROF_MAX, 0
pf_cur_hi       .fill PROF_MAX, 0
pf_fin_lo       .fill PROF_MAX, 0
pf_fin_hi       .fill PROF_MAX, 0

; --- evaluation ------------------------------------------------------
ev_score        .byte 0, 0      ; seize bits signes, en centipions
ev_mat          .byte 0, 0      ; matiere hors pions des deux camps
ev_tmp          .byte 0, 0
ev_piece        .byte 0
ev_type         .byte 0
ev_colonne      .byte 0
ev_case         .byte 0
ev_nb           .byte 0
ev_pions_b      .fill 8, 0      ; pions de chaque camp par colonne
ev_pions_n      .fill 8, 0

; --- recherche -------------------------------------------------------
rc_score        .byte 0, 0
rc_alpha        .byte 0, 0      ; fenetre de la racine
rc_alpha_fils   .byte 0, 0      ; fenetre passee au niveau suivant
rc_beta_fils    .byte 0, 0
rc_prof         .byte 0         ; profondeur de l'iteration en cours
rc_prof_fils    .byte 0
rc_prof_iter    .byte 0
rc_prof_faite   .byte 0         ; derniere profondeur menee a terme
rc_prof_max     .byte 0
rc_niv          .byte 0
rc_arret        .byte 0         ; 1 quand le temps est ecoule ou STOP
rc_trouve       .byte 0
rc_a_un_coup    .byte 0
rc_coup         .fill COUP_OCTETS, 0    ; coup retenu
rc_coup_iter    .fill COUP_OCTETS, 0    ; coup de l'iteration en cours
rc_score_iter   .byte 0, 0
rc_depart       .byte 0, 0      ; valeur de TI au debut de la reflexion
rc_ecoule       .byte 0, 0
rc_limite       .byte 0, 0
rc_compteur     .byte 0         ; pour ne pas lire l'horloge a chaque noeud
rc_tampon       .fill TOUCHES_MAX, 0    ; touches tapees pendant la reflexion
rc_tampon_e     .byte 0         ; ou ranger la prochaine
rc_tampon_s     .byte 0         ; ou prendre la plus ancienne
rc_nb_touches   .byte 0
rc_alea         .byte 1         ; graine du petit tirage des niveaux 1 et 2
rc_deb_rac      .byte 0, 0      ; bornes de la tranche de la racine
rc_fin_rac      .byte 0, 0
cm_deb          .byte 0, 0
cm_fin          .byte 0, 0
cm_garde        .byte 0, 0
cm_meilleur     .byte 0
cm_trouve       .byte 0
nc_note         .byte 0
gc_prises_seules .byte 0        ; 1 : la recherche de calme ne veut que
                                ; les prises et les promotions

; --- niveaux : profondeur visee et temps accorde, en jiffies ---------
;     Les trois premiers niveaux s'arretent a une profondeur fixe, les
;     trois derniers approfondissent tant qu'il leur reste du temps.
prof_niveau
        .byte 1, 2, 3, PROF_MAX, PROF_MAX, PROF_MAX
temps_niveau_lo
        .byte <60, <300, <900, <1800, <3600, <10800
temps_niveau_hi
        .byte >60, >300, >900, >1800, >3600, >10800
