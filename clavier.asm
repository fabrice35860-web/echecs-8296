; =====================================================================
;  clavier.asm - curseur, selection des pieces et saisie en notation
;
;  Deux facons de jouer, qui coexistent :
;    - au curseur : les fleches ou le pave numerique promenent le curseur,
;      RETURN ou ESPACE choisit une piece puis joue le coup ;
;    - en notation : taper une lettre ouvre la saisie ("E2-E4", "CG1-F3"),
;      RETURN joue le coup. DEL efface, la saisie vide referme le mode.
;
;  Les chiffres servent au pave numerique tant que la saisie n'est pas
;  ouverte ; une fois dedans, ils completent la notation. C'est ce qui
;  permet aux deux jeux de touches de ne pas se gener.
; =====================================================================

COL_SAISIE  = PAN_T+13      ; premiere colonne libre apres "VOTRE COUP : "

; ---------------------------------------------------------------------
;  clignoter : fait battre le curseur de case et celui de la saisie
;  La cadence vient de l'horloge systeme : le bit 4 des jiffies change
;  toutes les 16 images, soit environ trois fois par seconde en 50 Hz.
; ---------------------------------------------------------------------
clignoter
        lda JIFFY_LO
        and #$10
        cmp clign_phase
        beq cl_fin
        sta clign_phase
        lda curseur
        jsr dessiner_case
        jsr marquer_destinations    ; les prises possibles battent aussi
        jsr maj_curseur_texte
        jmp maj_pendule
cl_fin
        rts

; ---------------------------------------------------------------------
;  maj_saisie : redessine la ligne de saisie du panneau
;    "VOTRE COUP : "  puis, si une piece est choisie, "CG1-", puis les
;    caracteres tapes, puis le curseur clignotant.
; ---------------------------------------------------------------------
maj_saisie
        ; la case pointee par le curseur, sur la ligne du dessous
        lda #0
        sta attr_texte
        lda #LIG_CURSEUR
        jsr effacer_panneau_ligne
        lda #LIG_CURSEUR
        ldx #PAN_T
        jsr pos_ecran
        lda #<t_curseur
        sta ptr_texte
        lda #>t_curseur
        sta ptr_texte+1
        jsr afficher_texte
        lda curseur
        jsr nom_case
        ; puis la ligne de saisie proprement dite
        lda #LIG_SAISIE
        jsr effacer_panneau_ligne
        lda #LIG_SAISIE
        ldx #PAN_T
        jsr pos_ecran
        lda #<t_votre
        sta ptr_texte
        lda #>t_votre
        sta ptr_texte+1
        jsr afficher_texte
        ; afficher_texte laisse Y sur la fin de la chaine : on enchaine
        lda selection
        bmi ms_tapes
        ; rappel de la piece choisie et de sa case
        ldx selection
        lda plateau,x
        and #MASQUE_TYPE
        cmp #PION
        beq ms_sans_lettre
        tax
        lda lettres_pieces-1,x
        sta (ptr_ecran),y
        iny
ms_sans_lettre
        lda selection
        jsr nom_case
        lda #CAR_TIRET
        sta (ptr_ecran),y
        iny
ms_tapes
        ldx #0
ms_boucle
        cpx nb_saisie
        beq ms_curseur
        lda saisie,x
        jsr petscii_vers_ecran
        sta (ptr_ecran),y
        iny
        inx
        bne ms_boucle
ms_curseur
        ; colonne atteinte = PAN_T + Y
        tya
        clc
        adc #PAN_T
        sta col_curseur
        ; fallthrough

; ---------------------------------------------------------------------
;  maj_curseur_texte : curseur clignotant de la ligne de saisie
; ---------------------------------------------------------------------
maj_curseur_texte
        lda col_curseur
        cmp #PAN_X+PAN_L
        bcs mct_fin         ; la ligne est pleine : pas de curseur a poser
        lda #LIG_SAISIE
        ldx col_curseur
        jsr pos_ecran
        lda clign_phase
        beq mct_eteint
        lda #CAR_ESP_INV
        bne mct_pose
mct_eteint
        lda #CAR_ESPACE
mct_pose
        ldy #0
        sta (ptr_ecran),y
mct_fin
        rts

; ---------------------------------------------------------------------
;  petscii_vers_ecran : code ecran du caractere PETSCII A
;  Seuls les caracteres de la notation nous interessent : lettres
;  majuscules, chiffres, tiret.
; ---------------------------------------------------------------------
petscii_vers_ecran
        cmp #$40
        bcc pve_fin         ; chiffres et ponctuation : meme code
        and #$3F            ; lettres : $41..$5A -> $01..$1A
pve_fin
        rts

; ---------------------------------------------------------------------
;  deplacer_curseur : amene le curseur sur la case voisine, direction A
;  Le bord de l'echiquier arrete le curseur : il suffit de tester le
;  masque 0x88 de la case visee.
; ---------------------------------------------------------------------
deplacer_curseur
        tax
        lda dir_decalage,x
        clc
        adc curseur
        tax
        and #HORS_ECH
        bne dpc_fin         ; hors echiquier : on ne bouge pas
        lda curseur
        pha
        stx curseur         ; mis a jour avant les redessins, pour que
        pla                 ; l'ancienne case perde bien son curseur
        jsr dessiner_case
        lda curseur
        jsr dessiner_case
        jmp maj_saisie
dpc_fin
        rts

; ---------------------------------------------------------------------
;  aller_case : amene le curseur sur la case A (saisie en notation)
; ---------------------------------------------------------------------
aller_case
        cmp curseur
        beq ac_fin
        sta pz_tmp
        lda curseur
        pha
        lda pz_tmp
        sta curseur
        pla
        jsr dessiner_case
        lda curseur
        jmp dessiner_case
ac_fin
        rts

; ---------------------------------------------------------------------
;  valider : RETURN ou ESPACE sur la case pointee par le curseur
; ---------------------------------------------------------------------
valider
        lda partie_finie
        beq val_en_cours
        jmp val_terminee
val_en_cours
        lda curseur
        jsr piece_au_trait
        bne val_pas_a_nous
        ; une de nos pieces : choix, changement de choix ou relachement
        lda curseur
        cmp selection
        beq val_relacher
        ; une piece sans coup legal ne se choisit pas
        lda curseur
        jsr piece_jouable
        bcc val_aucun_coup
        jsr effacer_destinations    ; l'ancien choix s'efface d'abord
        lda curseur
        sta selection
        jsr marquer_destinations
        jsr maj_saisie
        jmp message_selection

val_aucun_coup
        lda #<t_m_aucun_coup
        ldx #>t_m_aucun_coup
        jmp message

val_terminee
        lda #<t_m_finie
        ldx #>t_m_finie
        jmp message

val_relacher
        jmp deselectionner

val_pas_a_nous
        ; pas une de nos pieces : destination si une piece est choisie
        lda selection
        bmi val_sans_choix
        lda selection
        sta cp_depart
        lda curseur
        sta cp_arrivee
        jsr coup_possible
        bne val_refuse
        jmp jouer_coup
val_refuse
        lda #<t_m_impossible
        ldx #>t_m_impossible
        jmp message

val_sans_choix
        ldx curseur
        lda plateau,x
        beq val_case_vide
        ; une piece adverse
        lda #<t_m_adverse
        ldx #>t_m_adverse
        jsr message
        lda #<t_m_adverse2
        ldx #>t_m_adverse2
        jmp message2
val_case_vide
        lda #<t_m_vide
        ldx #>t_m_vide
        jsr message
        lda #<t_m_vos_pieces
        ldx #>t_m_vos_pieces
        jmp message2

; ---------------------------------------------------------------------
;  deselectionner : relache la piece choisie et efface son marquage
; ---------------------------------------------------------------------
deselectionner
        lda selection
        bmi ds_fin
        jsr effacer_destinations
        jsr maj_saisie
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp message_trait
ds_fin
        rts

; ---------------------------------------------------------------------
;  message_selection : "CAVALIER G1 SELECTIONNE" / "DESTINATION ?"
; ---------------------------------------------------------------------
message_selection
        lda #LIG_MSG
        jsr effacer_panneau_ligne
        lda #0
        sta attr_texte
        lda #LIG_MSG
        ldx #PAN_T
        jsr pos_ecran
        ; nom de la piece
        ldx selection
        lda plateau,x
        and #MASQUE_TYPE
        tax
        lda nom_piece_lo-1,x
        sta ptr_texte
        lda nom_piece_hi-1,x
        sta ptr_texte+1
        jsr afficher_texte
        jsr avancer_ecran
        ; un espace, le nom de la case, un espace
        lda #CAR_ESPACE
        sta (ptr_ecran),y
        iny
        lda selection
        jsr nom_case
        lda #CAR_ESPACE
        sta (ptr_ecran),y
        iny
        jsr avancer_ecran
        lda #<t_m_select
        sta ptr_texte
        lda #>t_m_select
        sta ptr_texte+1
        jsr afficher_texte
        lda #<t_m_destination
        ldx #>t_m_destination
        jmp message2

; ---------------------------------------------------------------------
;  traiter_touche : aiguille la touche A
; ---------------------------------------------------------------------
traiter_touche
        ldx attente_conf
        beq +
        jmp tt_confirmation
+       ldx attente_promo
        beq +
        jmp tt_promotion
+
        ; --- touches toujours actives ---
        cmp #TOUCHE_RET
        beq tt_return
        cmp #TOUCHE_ESP
        beq tt_espace
        cmp #TOUCHE_DEL
        beq tt_effacer
        cmp #TOUCHE_AIDE
        beq tt_aide
        ; --- chiffres : pave numerique, ou notation si la saisie est ouverte
        cmp #$31            ; "1"
        bcc tt_commandes
        cmp #$39+1
        bcs tt_commandes
        ldx nb_saisie
        bne tt_vers_taper
        jmp tt_navigation
tt_vers_taper
        jmp taper
tt_return
        jmp tt_valider
tt_espace
        lda nb_saisie
        bne tt_rien         ; en pleine saisie, ESPACE ne vaut rien
        jmp valider
tt_effacer
        jmp effacer_saisie
tt_aide
        jmp afficher_aide
tt_rien
        rts

tt_commandes
        ; --- lettres qui ouvrent la saisie en notation ---
        cmp #$41            ; A
        bcc tt_autres
        cmp #$48+1          ; H : les huit colonnes
        bcc tt_vers_taper
        cmp #TOUCHE_O       ; O : le roque
        beq tt_vers_taper
        cmp #$50            ; P : pion
        beq tt_vers_taper
        cmp #$52            ; R : roi
        beq tt_vers_taper
        cmp #$54            ; T : tour
        beq tt_vers_taper
        ; --- commandes ---
        ; Chacune passe par un saut long : les traitements qui suivent ont
        ; grossi au point qu'un branchement court ne porte plus assez loin.
        cmp #TOUCHE_U
        bne +
        jmp tt_annuler
+       cmp #TOUCHE_N
        bne +
        jmp tt_nouvelle
+       cmp #TOUCHE_Q
        bne +
        jmp tt_quitter
+       cmp #TOUCHE_L
        bne +
        jmp tt_niveau
+       cmp #TOUCHE_J
        bne +
        jmp tt_ordi
+       cmp #TOUCHE_M
        bne tt_autres
        jmp tt_menu
tt_autres
        ; --- reste les touches de deplacement du curseur ---
tt_navigation
        ldx #0
tn_boucle
        cmp nav_touches,x
        beq tn_trouve
        inx
        cpx #NAV_NOMBRE
        bne tn_boucle
        rts
tn_trouve
        lda nav_directions,x
        jmp deplacer_curseur

tt_valider
        lda nb_saisie
        beq tt_val_curseur
        jmp valider_saisie
tt_val_curseur
        jmp valider

; tt_promotion : la partie attend de savoir en quoi le pion se change.
; RETURN vaut la dame ; une autre touche que D, T, F ou C ne fait rien.
tt_promotion
        cmp #TOUCHE_RET
        bne +
        lda #$44            ; D comme dame
+       jmp jouer_promo

tt_ordi
        jmp changer_camp_ordi

; U : revenir en arriere. Un seul demi-coup defait ne suffit pas quand
; l'ordinateur tient un camp : la main lui reviendrait, et il rejouerait
; aussitot le coup qu'on vient d'effacer. On remonte donc d'un demi-coup
; de plus, de facon que le joueur retrouve vraiment le trait et puisse
; choisir autre chose. S'il ne reste rien a defaire -- l'ordinateur tient
; les Blancs et c'est son premier coup -- on s'arrete la.
tt_annuler
        jsr annuler_coup
        bne tta_rien
        lda camp_ordi
        cmp #ORDI_AUCUN     ; deux joueurs humains : un demi-coup suffit
        beq tta_fait
        cmp trait           ; la main est-elle revenue a l'ordinateur ?
        bne tta_fait
        jsr annuler_coup
tta_fait
        lda #<t_m_annule
        ldx #>t_m_annule
        jsr message
        jmp message_trait
tta_rien
        lda #<t_m_rien_annul
        ldx #>t_m_rien_annul
        jmp message

tt_nouvelle
        lda #1
        sta attente_conf
        lda #<t_m_conf_nouv
        ldx #>t_m_conf_nouv
        jsr message
        lda #<t_m_conf_rep
        ldx #>t_m_conf_rep
        jmp message2

tt_quitter
        lda #2
        sta attente_conf
        lda #<t_m_conf_fin
        ldx #>t_m_conf_fin
        jsr message
        lda #<t_m_conf_rep
        ldx #>t_m_conf_rep
        jmp message2

tt_niveau
        lda #3
        sta attente_conf
        lda #<t_m_niveau
        ldx #>t_m_niveau
        jmp message

tt_menu
        lda #1
        sta retour_menu
        rts

; ---------------------------------------------------------------------
;  tt_confirmation : reponse attendue a une question du panneau
; ---------------------------------------------------------------------
tt_confirmation
        ; A porte la touche, X la question posee (attente_conf)
        ldy #0
        sty attente_conf
        cpx #3
        beq ttc_niveau
        cpx #2
        beq ttc_fin
        ; nouvelle partie
        cmp #TOUCHE_OUI
        bne ttc_annule
        jmp nouvelle_partie
ttc_fin
        cmp #TOUCHE_OUI
        bne ttc_annule
        lda #1
        sta demande_fin
        rts
ttc_niveau
        cmp #$31            ; "1"
        bcc ttc_annule
        cmp #$30+NB_NIVEAUX+1
        bcs ttc_annule
        sec
        sbc #$30
        sta niveau
        jsr maj_panneau
ttc_annule
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp message_trait

; ---------------------------------------------------------------------
;  Saisie en notation
; ---------------------------------------------------------------------
taper
        ldx nb_saisie
        cpx #SAISIE_MAX
        bcs tap_fin
        sta saisie,x
        inc nb_saisie
        jmp maj_saisie
tap_fin
        rts

effacer_saisie
        lda nb_saisie
        beq es_fin
        dec nb_saisie
        jmp maj_saisie
es_fin
        rts

; ---------------------------------------------------------------------
;  valider_saisie : analyse ce qui a ete tape et le joue
; ---------------------------------------------------------------------
valider_saisie
        jsr analyser_saisie
        cmp #2
        bcs vs_roque        ; 2 = petit roque, 3 = grand
        cmp #0
        bne vs_invalide
        ; case de depart seule : on y amene le curseur et on choisit
        lda sa_arrivee
        bmi vs_choisir
        ; coup complet : la case de depart doit porter une de nos pieces
        lda sa_depart
        jsr piece_au_trait
        bne vs_pas_a_nous
        lda sa_depart
        sta cp_depart
        lda sa_arrivee
        sta cp_arrivee
        jsr coup_possible
        bne vs_impossible
        lda #0
        sta nb_saisie
        lda sa_depart
        sta selection
        jmp jouer_coup
vs_choisir
        lda #0
        sta nb_saisie
        lda sa_depart
        jsr aller_case
        jsr maj_saisie
        jmp valider
vs_pas_a_nous
        lda #0
        sta nb_saisie
        jsr maj_saisie
        lda #<t_m_adverse
        ldx #>t_m_adverse
        jsr message
        lda #<t_m_adverse2
        ldx #>t_m_adverse2
        jmp message2
vs_impossible
        lda #0
        sta nb_saisie
        jsr maj_saisie
        lda #<t_m_impossible
        ldx #>t_m_impossible
        jmp message
vs_invalide
        lda #0
        sta nb_saisie
        jsr maj_saisie
        lda #<t_m_saisie_nok
        ldx #>t_m_saisie_nok
        jmp message
; vs_roque : A vaut 2 pour le petit roque, 3 pour le grand. Les deux
; cases se deduisent du camp au trait ; c'est ensuite un coup comme un
; autre, que coup_possible accepte ou non.
vs_roque
        pha
        lda #0
        sta nb_saisie
        jsr maj_saisie
        lda #0
        ldx trait
        beq vsr_rang
        lda #RANGEE_8
vsr_rang
        sta pz_tmp
        lda #CASE_E1
        clc
        adc pz_tmp
        sta cp_depart
        pla
        cmp #3
        beq vsr_grand
        lda #CASE_G1
        bne vsr_poser
vsr_grand
        lda #CASE_C1
vsr_poser
        clc
        adc pz_tmp
        sta cp_arrivee
        jsr coup_possible
        bne vsr_non
        lda cp_depart
        sta selection
        jmp jouer_coup
vsr_non
        lda #<t_m_roque_nok
        ldx #>t_m_roque_nok
        jmp message

; ---------------------------------------------------------------------
;  analyser_saisie : decode le tampon de saisie
;  Sortie  A = 0 coup lu (sa_depart, sa_arrivee ; sa_arrivee = $FF quand
;                seule la case de depart a ete donnee)
;          A = 1 saisie incomprehensible
;          A = 2 roque
;
;  "CG1-F3" et "C3-D4" se distinguent par le deuxieme caractere : un
;  chiffre fait du premier une colonne, une lettre en fait l'initiale
;  d'une piece.
; ---------------------------------------------------------------------
analyser_saisie
        lda #$FF
        sta sa_arrivee
        lda nb_saisie
        beq as_invalide
        lda saisie
        cmp #TOUCHE_O
        beq as_roque
        lda #0
        sta sa_index
        ; initiale de piece a sauter ?
        lda nb_saisie
        cmp #2
        bcc as_depart
        lda saisie+1
        jsr est_chiffre
        bcs as_depart       ; chiffre : le premier caractere est la colonne
        inc sa_index        ; sinon c'etait l'initiale d'une piece
as_depart
        jsr lire_case
        bcs as_invalide
        sta sa_depart
        ; fin de la saisie : seule la case de depart a ete donnee
        lda sa_index
        cmp nb_saisie
        beq as_ok
        ; separateur facultatif
        ldx sa_index
        lda saisie,x
        cmp #CAR_TIRET
        beq as_separateur
        cmp #$58            ; X, pour une prise
        bne as_arrivee
as_separateur
        inc sa_index
as_arrivee
        jsr lire_case
        bcs as_invalide
        sta sa_arrivee
        lda sa_index
        cmp nb_saisie
        bne as_invalide     ; des caracteres en trop
as_ok
        lda #0
        rts
as_invalide
        lda #1
        rts
; Le nombre de O separe les deux roques : "O-O" en a deux, "O-O-O" trois.
as_roque
        ldx #0
        ldy #0
asr_compter
        lda saisie,y
        cmp #TOUCHE_O
        bne asr_suivant
        inx
asr_suivant
        iny
        cpy nb_saisie
        bcc asr_compter
        cpx #3
        bcc asr_petit
        lda #3
        rts
asr_petit
        lda #2
        rts

; ---------------------------------------------------------------------
;  lire_case : lit une colonne et une rangee a partir de saisie+sa_index
;  Sortie  A = index 0x88, C = 0 ; C = 1 si ce n'est pas une case
; ---------------------------------------------------------------------
lire_case
        ldx sa_index
        inx
        cpx nb_saisie
        bcs lc_erreur       ; il faut deux caracteres
        ldx sa_index
        lda saisie,x
        cmp #$41            ; A
        bcc lc_erreur
        cmp #$48+1          ; H
        bcs lc_erreur
        sec
        sbc #$41
        sta pz_tmp          ; colonne 0..7
        inx
        lda saisie,x
        cmp #$31            ; 1
        bcc lc_erreur
        cmp #$38+1          ; 8
        bcs lc_erreur
        sec
        sbc #$31            ; rangee 0..7
        asl a
        asl a
        asl a
        asl a               ; x16
        clc
        adc pz_tmp
        sta pz_tmp2
        lda sa_index
        clc
        adc #2
        sta sa_index
        lda pz_tmp2
        clc                 ; C = 0 : lecture reussie
        rts
lc_erreur
        sec
        rts

; est_chiffre : C = 1 si A est un chiffre PETSCII
est_chiffre
        cmp #$30
        bcc ec_non
        cmp #$39+1
        bcs ec_non
        sec
        rts
ec_non
        clc
        rts

; ---------------------------------------------------------------------
;  afficher_aide : l'ecran des touches, jusqu'a la prochaine touche
; ---------------------------------------------------------------------
afficher_aide
        jsr effacer_ecran
        lda #LIG_TITRE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #LARGEUR
        jsr remplir
        lda #<aide_textes
        sta ptr_aux
        lda #>aide_textes
        sta ptr_aux+1
        jsr afficher_table
-       jsr GETIN
        beq -
        jmp redessiner_tout
