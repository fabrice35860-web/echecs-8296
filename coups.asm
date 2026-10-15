; =====================================================================
;  coups.asm - generateur de coups, attaques, make / unmake
;
;  Tout ce fichier travaille sur le plateau 0x88 sans jamais toucher a
;  l'ecran : il sert aussi bien a la partie qu'au programme de validation
;  perft.asm et, a l'etape 3, a la recherche.
;
;  Un coup tient sur quatre octets : depart, arrivee, drapeau, score.
;  Les coups sont ranges a la suite a partir de coups_fin, qui avance ;
;  chaque niveau de recursion garde le debut de sa tranche et la rend en
;  repartant. Rien n'est alloue a l'avance : une position de milieu de
;  partie tient dans 150 octets, ce qui laisse de la place pour une
;  cinquantaine de demi-coups empiles.
; =====================================================================

; ---------------------------------------------------------------------
;  ajouter_coup : range gc_depart -> gc_arrivee (drapeau gc_drapeau)
;  La zone des coups est bornee : au-dela on cesse d'ajouter plutot que
;  d'ecrire au hasard dans la memoire.
; ---------------------------------------------------------------------
ajouter_coup
        lda gc_prises_seules
        beq ac_garder
        ; recherche de calme : on laisse tomber les coups tranquilles
        lda gc_drapeau
        cmp #CP_PROMO
        bcs ac_garder
        cmp #CP_EP
        beq ac_garder
        ldx gc_arrivee
        lda plateau,x
        beq ac_plein
ac_garder
        lda coups_fin+1
        cmp #>(coups_zone+TAILLE_COUPS-COUP_OCTETS)
        bcc ac_place
        lda coups_fin
        cmp #<(coups_zone+TAILLE_COUPS-COUP_OCTETS)
        bcs ac_plein
ac_place
        ldy #0
        lda gc_depart
        sta (coups_fin),y
        iny
        lda gc_arrivee
        sta (coups_fin),y
        iny
        lda gc_drapeau
        sta (coups_fin),y
        iny
        lda #0
        sta (coups_fin),y
        lda coups_fin
        clc
        adc #COUP_OCTETS
        sta coups_fin
        bcc +
        inc coups_fin+1
+       inc gc_nb
ac_plein
        rts

; ---------------------------------------------------------------------
;  generer_coups : tous les coups pseudo-legaux du camp au trait
;  Entree  coups_fin = debut de la tranche a remplir
;  Sortie  coups_fin = fin de la tranche, gc_nb = nombre de coups
;
;  Pseudo-legaux : un coup qui laisse son propre roi en echec figure
;  encore dans la liste ; c'est coup_legal qui le refuse. Les roques, eux,
;  sont deja verifies ici, cases traversees comprises.
; ---------------------------------------------------------------------
generer_coups
        lda #0
        sta gc_nb
        sta gc_depart
gc_case
        ldx gc_depart
        lda plateau,x
        beq gc_sauter
        sta gc_piece
        and #MASQUE_COUL
        cmp trait
        beq gc_type
gc_sauter
        jmp gc_suivant
gc_type
        lda gc_piece
        and #MASQUE_TYPE
        cmp #PION
        bne +
        jmp gc_pion
+       cmp #CAVALIER
        beq gc_cavalier
        cmp #ROI
        beq gc_roi
        ; fou, tour, dame : les pieces qui glissent
        lda gc_piece
        and #MASQUE_TYPE
        tax
        lda dir_fin,x
        sta gc_dfin
        lda dir_deb,x
        sta gc_dir
gc_gl_dir
        ldx gc_dir
        lda dir_toutes,x
        sta gc_pas
        lda gc_depart
gc_gl_pas
        clc
        adc gc_pas
        tax
        and #HORS_ECH
        bne gc_gl_fin_dir
        lda plateau,x
        beq gc_gl_vide
        and #MASQUE_COUL
        cmp trait
        beq gc_gl_fin_dir   ; piece amie : la direction s'arrete avant
        stx gc_arrivee
        jsr gc_simple
        jmp gc_gl_fin_dir   ; prise : la direction s'arrete dessus
gc_gl_vide
        stx gc_arrivee
        jsr gc_simple
        lda gc_arrivee
        jmp gc_gl_pas
gc_gl_fin_dir
        inc gc_dir
        lda gc_dfin
        cmp gc_dir
        bcs gc_gl_dir
        jmp gc_suivant

; --- cavalier et roi : un seul pas, meme boucle ----------------------
gc_cavalier
        lda #DIR_CAVAL
        sta gc_dir
        lda #DIR_DERN
        sta gc_dfin
        jmp gc_saut
gc_roi
        lda #DIR_ORTHO
        sta gc_dir
        lda #DIR_DIAG+3
        sta gc_dfin
gc_saut
        ldx gc_dir
        lda dir_toutes,x
        clc
        adc gc_depart
        tax
        and #HORS_ECH
        bne gc_saut_suite
        lda plateau,x
        beq gc_saut_ok
        and #MASQUE_COUL
        cmp trait
        beq gc_saut_suite
gc_saut_ok
        stx gc_arrivee
        jsr gc_simple
gc_saut_suite
        inc gc_dir
        lda gc_dfin
        cmp gc_dir
        bcs gc_saut
        ; le roi ajoute ses roques
        lda gc_piece
        and #MASQUE_TYPE
        cmp #ROI
        bne gc_suivant
        jsr gc_roques
        jmp gc_suivant

; --- passage a la case suivante --------------------------------------
;     En 0x88, apres la colonne 7 viennent huit cases fictives : on les
;     saute d'un coup.
gc_suivant
        inc gc_depart
        lda gc_depart
        and #HORS_ECH
        beq gc_reprendre
        lda gc_depart
        clc
        adc #8
        sta gc_depart
        cmp #$80
        bcs gc_termine
gc_reprendre
        jmp gc_case
gc_termine
        rts

; gc_simple : un coup ordinaire, sans drapeau
gc_simple
        lda #CP_NORMAL
        sta gc_drapeau
        jmp ajouter_coup

; ---------------------------------------------------------------------
;  Pions : avance simple, double pas, deux prises, prise en passant,
;  promotion. Un pion n'est jamais sur sa derniere rangee (il aurait
;  promu), donc l'avance simple ne peut pas sortir de l'echiquier.
; ---------------------------------------------------------------------
gc_pion
        lda trait
        bne gcp_noir
        lda #DEP_HAUT
        sta gc_pas
        lda #RANG_2_B
        sta gc_rang2
        lda #RANG_PROMO_B
        sta gc_rangp
        jmp gcp_avance
gcp_noir
        lda #DEP_BAS
        sta gc_pas
        lda #RANG_2_N
        sta gc_rang2
        lda #RANG_PROMO_N
        sta gc_rangp
gcp_avance
        lda gc_depart
        clc
        adc gc_pas
        tax
        lda plateau,x
        bne gcp_prises
        stx gc_arrivee
        jsr gcp_poser
        ; double pas, seulement depuis la rangee de depart
        lda gc_depart
        and #$F0
        cmp gc_rang2
        bne gcp_prises
        lda gc_depart
        clc
        adc gc_pas
        clc
        adc gc_pas
        tax
        lda plateau,x
        bne gcp_prises
        stx gc_arrivee
        lda #CP_DOUBLE
        sta gc_drapeau
        jsr ajouter_coup
gcp_prises
        lda #0
        sta gc_dir          ; 0 = vers la colonne A, 1 = vers la colonne H
gcp_pr_boucle
        lda gc_pas
        ldx gc_dir
        beq gcp_pr_gauche
        clc
        adc #1
        jmp gcp_pr_case
gcp_pr_gauche
        sec
        sbc #1
gcp_pr_case
        clc
        adc gc_depart
        sta gc_arrivee
        and #HORS_ECH
        bne gcp_pr_suite
        ldx gc_arrivee
        lda plateau,x
        beq gcp_pr_ep
        and #MASQUE_COUL
        cmp trait
        beq gcp_pr_suite    ; piece amie
        jsr gcp_poser
        jmp gcp_pr_suite
gcp_pr_ep
        lda case_ep
        cmp gc_arrivee
        bne gcp_pr_suite
        lda #CP_EP
        sta gc_drapeau
        jsr ajouter_coup
gcp_pr_suite
        inc gc_dir
        lda gc_dir
        cmp #2
        bcc gcp_pr_boucle
        jmp gc_suivant

; gcp_poser : pose le coup du pion, en quatre exemplaires s'il promeut
gcp_poser
        lda gc_arrivee
        and #$F0
        cmp gc_rangp
        beq gcp_promo
        lda #CP_NORMAL
        sta gc_drapeau
        jmp ajouter_coup
gcp_promo
        ldx #3
gcp_promo_b
        stx gc_dfin         ; gc_dfin est libre ici : il sert de compteur
        lda promo_types,x
        ora #CP_PROMO
        sta gc_drapeau
        jsr ajouter_coup
        ldx gc_dfin
        dex
        bpl gcp_promo_b
        rts

; ---------------------------------------------------------------------
;  gc_roques : ajoute les roques encore permis au camp au trait
;  Conditions completes : droit encore ouvert, cases intermediaires
;  vides, roi ni en echec, ni traversant, ni arrivant sur une case
;  attaquee. L'arrivee est verifiee ici aussi, ce qui evite d'en
;  dependre du filtre de legalite.
; ---------------------------------------------------------------------
gc_roques
        lda #0
        ldx trait
        beq gcr_rang
        lda #RANGEE_8
gcr_rang
        sta gc_rang2        ; decalage de rangee du camp au trait
        ; le roi doit etre sur sa case d'origine
        lda #CASE_E1
        clc
        adc gc_rang2
        cmp gc_depart
        beq gcr_petit
        rts
gcr_petit
        ; --- petit roque ---
        lda #ROQUE_BP
        ldx trait
        beq gcr_pdroit
        lda #ROQUE_NP
gcr_pdroit
        and droits_roque
        beq gcr_grand
        ldx #CASE_F1
        jsr gcr_vide
        bcc gcr_grand
        ldx #CASE_G1
        jsr gcr_vide
        bcc gcr_grand
        ldx #CASE_E1        ; les trois cases du roi, non attaquees
        jsr gcr_sure
        bcc gcr_grand
        ldx #CASE_F1
        jsr gcr_sure
        bcc gcr_grand
        ldx #CASE_G1
        jsr gcr_sure
        bcc gcr_grand
        lda #CASE_G1
        clc
        adc gc_rang2
        sta gc_arrivee
        lda #CP_PETIT
        sta gc_drapeau
        jsr ajouter_coup
gcr_grand
        lda #ROQUE_BG
        ldx trait
        beq gcr_gdroit
        lda #ROQUE_NG
gcr_gdroit
        and droits_roque
        beq gcr_fin
        ldx #CASE_B1
        jsr gcr_vide
        bcc gcr_fin
        ldx #CASE_C1
        jsr gcr_vide
        bcc gcr_fin
        ldx #CASE_D1
        jsr gcr_vide
        bcc gcr_fin
        ldx #CASE_E1
        jsr gcr_sure
        bcc gcr_fin
        ldx #CASE_D1
        jsr gcr_sure
        bcc gcr_fin
        ldx #CASE_C1
        jsr gcr_sure
        bcc gcr_fin
        lda #CASE_C1
        clc
        adc gc_rang2
        sta gc_arrivee
        lda #CP_GRAND
        sta gc_drapeau
        jsr ajouter_coup
gcr_fin
        rts

; gcr_vide : la case X du camp au trait est-elle libre ? C = 1 si oui
gcr_vide
        txa
        clc
        adc gc_rang2
        tax
        lda plateau,x
        beq +
        clc
        rts
+       sec
        rts

; gcr_sure : la case X du camp au trait echappe-t-elle a l'adversaire ?
gcr_sure
        txa
        clc
        adc gc_rang2
        pha
        lda trait
        eor #NOIR
        tax                 ; camp attaquant
        pla
        jsr est_attaquee
        ; est_attaquee rend C = 1 quand la case est attaquee : on inverse
        php
        pla
        eor #1
        pha
        plp
        rts

; ---------------------------------------------------------------------
;  est_attaquee : la case A est-elle attaquee par le camp X ?
;  Sortie  C = 1 si oui
;
;  On interroge la case dans toutes les directions plutot que de passer
;  en revue les pieces adverses : c'est le meme travail pour un roi seul,
;  et beaucoup moins pour une position pleine.
; ---------------------------------------------------------------------
est_attaquee
        sta ea_case
        stx ea_camp
        ; --- cavaliers ---
        ldy #DIR_DERN
ea_cav
        lda dir_toutes,y
        clc
        adc ea_case
        tax
        and #HORS_ECH
        bne ea_cav_suite
        lda plateau,x
        beq ea_cav_suite
        sta ea_piece
        and #MASQUE_COUL
        cmp ea_camp
        bne ea_cav_suite
        lda ea_piece
        and #MASQUE_TYPE
        cmp #CAVALIER
        bne ea_cav_suite
        jmp ea_oui
ea_cav_suite
        dey
        cpy #DIR_CAVAL
        bcs ea_cav
        ; --- roi et pions : les huit cases voisines ---
        ldy #DIR_DIAG+3
ea_adj
        lda dir_toutes,y
        clc
        adc ea_case
        tax
        and #HORS_ECH
        bne ea_adj_suite
        lda plateau,x
        beq ea_adj_suite
        sta ea_piece
        and #MASQUE_COUL
        cmp ea_camp
        bne ea_adj_suite
        lda ea_piece
        and #MASQUE_TYPE
        cmp #ROI
        beq ea_oui
        cmp #PION
        bne ea_adj_suite
        ; Un pion ne prend qu'en diagonale et vers l'avant. Vu depuis la
        ; case visee, un pion blanc vient donc des directions BD ou BG
        ; (indices 6 et 7), un pion noir des directions HD ou HG (4 et 5).
        cpy #DIR_DIAG
        bcc ea_adj_suite    ; direction orthogonale : pas une prise
        lda ea_camp
        bne ea_pion_noir
        cpy #DIR_DIAG+2
        bcs ea_oui
        bcc ea_adj_suite
ea_pion_noir
        cpy #DIR_DIAG+2
        bcc ea_oui
ea_adj_suite
        dey
        bpl ea_adj
        ; --- pieces qui glissent : tours et dames en ligne, fous et
        ;     dames en diagonale ---
        ldy #DIR_DIAG+3
ea_gl
        lda dir_toutes,y
        sta ea_pas
        lda ea_case
ea_gl_pas
        clc
        adc ea_pas
        tax
        and #HORS_ECH
        bne ea_gl_suite
        lda plateau,x
        beq ea_gl_continuer
        sta ea_piece
        and #MASQUE_COUL
        cmp ea_camp
        bne ea_gl_suite     ; piece amie de la case visee : elle bloque
        lda ea_piece
        and #MASQUE_TYPE
        cmp #DAME
        beq ea_oui
        cpy #DIR_DIAG
        bcs ea_gl_fou
        cmp #TOUR
        beq ea_oui
        bne ea_gl_suite
ea_gl_fou
        cmp #FOU
        beq ea_oui
        bne ea_gl_suite
ea_gl_continuer
        txa
        jmp ea_gl_pas
ea_gl_suite
        dey
        bpl ea_gl
        clc
        rts
ea_oui
        sec
        rts

; ---------------------------------------------------------------------
;  roi_en_echec : le roi du camp A est-il attaque ?
;  Sortie  C = 1 si oui
; ---------------------------------------------------------------------
roi_en_echec
        pha
        lsr a
        lsr a
        lsr a
        tax
        lda pos_roi,x
        tay
        pla
        eor #NOIR
        tax                 ; camp attaquant
        tya
        jmp est_attaquee

; ---------------------------------------------------------------------
;  charger_coup : lit les quatre octets pointes par ptr_coup
; ---------------------------------------------------------------------
charger_coup
        ldy #0
        lda (ptr_coup),y
        sta cp_depart
        iny
        lda (ptr_coup),y
        sta cp_arrivee
        iny
        lda (ptr_coup),y
        sta cp_drapeau
        rts

; ---------------------------------------------------------------------
;  pos_hist : ptr_hist pointe l'entree numero nb_demi_coups de la pile,
;  soit la premiere entree libre. Huit octets par demi-coup.
; ---------------------------------------------------------------------
pos_hist
        lda nb_demi_coups
        sta ptr_hist
        lda nb_demi_hi
        sta ptr_hist+1
        asl ptr_hist
        rol ptr_hist+1
        asl ptr_hist
        rol ptr_hist+1
        asl ptr_hist
        rol ptr_hist+1
        lda ptr_hist
        clc
        adc #<hist_zone
        sta ptr_hist
        lda ptr_hist+1
        adc #>hist_zone
        sta ptr_hist+1
        rts

; ---------------------------------------------------------------------
;  jouer_interne : applique le coup cp_depart -> cp_arrivee, drapeau
;  cp_drapeau, et empile de quoi le defaire. Aucun affichage.
; ---------------------------------------------------------------------
jouer_interne
        ldx cp_depart
        lda plateau,x
        sta cp_piece
        ; la piece prise : sous la case d'arrivee, sauf en passant
        lda cp_drapeau
        cmp #CP_EP
        beq ji_prise_ep
        ldx cp_arrivee
        lda plateau,x
        sta cp_prise
        jmp ji_empiler
ji_prise_ep
        jsr ji_case_pion_ep
        lda plateau,x
        sta cp_prise
ji_empiler
        jsr pos_hist
        ldy #0
        lda cp_depart
        sta (ptr_hist),y
        iny
        lda cp_arrivee
        sta (ptr_hist),y
        iny
        lda cp_piece
        sta (ptr_hist),y
        iny
        lda cp_prise
        sta (ptr_hist),y
        iny
        lda droits_roque
        sta (ptr_hist),y
        iny
        lda case_ep
        sta (ptr_hist),y
        iny
        lda demi_50
        sta (ptr_hist),y
        iny
        lda cp_drapeau
        sta (ptr_hist),y
        inc nb_demi_coups
        bne +
        inc nb_demi_hi
+
        ; --- la piece quitte sa case ---
        ldx cp_depart
        lda #VIDE
        sta plateau,x
        ; --- ce qui se pose sur la case d'arrivee ---
        lda cp_drapeau
        cmp #CP_PROMO
        bcc ji_poser_piece
        and #MASQUE_TYPE
        sta ji_tmp
        lda cp_piece
        and #MASQUE_COUL
        ora ji_tmp
        jmp ji_poser
ji_poser_piece
        lda cp_piece
ji_poser
        ldx cp_arrivee
        sta plateau,x
        ; --- les coups a deux temps ---
        lda cp_drapeau
        cmp #CP_EP
        beq ji_ep
        cmp #CP_PETIT
        beq ji_petit
        cmp #CP_GRAND
        beq ji_grand
        jmp ji_droits
ji_ep
        jsr ji_case_pion_ep
        lda #VIDE
        sta plateau,x
        jmp ji_droits
ji_petit
        ldx cp_arrivee      ; la tour saute de H a F
        inx
        lda plateau,x
        sta ji_tmp
        lda #VIDE
        sta plateau,x
        ldx cp_arrivee
        dex
        lda ji_tmp
        sta plateau,x
        jmp ji_droits
ji_grand
        lda cp_arrivee      ; la tour saute de A a D
        sec
        sbc #2
        tax
        lda plateau,x
        sta ji_tmp
        lda #VIDE
        sta plateau,x
        ldx cp_arrivee
        inx
        lda ji_tmp
        sta plateau,x
ji_droits
        ; --- droits de roque : le depart comme l'arrivee peuvent en
        ;     retirer (roi ou tour qui bouge, tour prise sur sa case) ---
        ldx cp_depart
        jsr maj_roque
        ldx cp_arrivee
        jsr maj_roque
        ; --- case de prise en passant ---
        lda cp_drapeau
        cmp #CP_DOUBLE
        bne ji_pas_ep
        lda cp_depart
        clc
        adc cp_arrivee
        lsr a               ; la case traversee est leur milieu
        sta case_ep
        jmp ji_cinquante
ji_pas_ep
        lda #AUCUNE_CASE
        sta case_ep
ji_cinquante
        ; --- regle des 50 coups : remise a zero sur prise ou coup de pion
        lda cp_prise
        bne ji_remise
        lda cp_piece
        and #MASQUE_TYPE
        cmp #PION
        beq ji_remise
        inc demi_50
        jmp ji_roi
ji_remise
        lda #0
        sta demi_50
ji_roi
        ; --- le roi a-t-il bouge ? ---
        lda cp_piece
        and #MASQUE_TYPE
        cmp #ROI
        bne ji_trait
        lda cp_piece
        and #MASQUE_COUL
        lsr a
        lsr a
        lsr a
        tax
        lda cp_arrivee
        sta pos_roi,x
ji_trait
        lda trait
        eor #NOIR
        sta trait
        rts

; ji_case_pion_ep : X = case du pion capture en passant. Le pion est a
; cote de la case d'arrivee, pas dessus : une rangee en dessous pour une
; prise des Blancs, une rangee au-dessus pour les Noirs.
ji_case_pion_ep
        lda cp_piece
        and #MASQUE_COUL
        bne jcp_noir
        lda cp_arrivee
        clc
        adc #DEP_BAS
        tax
        rts
jcp_noir
        lda cp_arrivee
        clc
        adc #DEP_HAUT
        tax
        rts

; maj_roque : la case X vient d'etre quittee ou prise ; retire le droit
; de roque correspondant s'il y en a un.
maj_roque
        ldy #5
mr_boucle
        txa
        cmp roque_cases,y
        bne +
        lda droits_roque
        and roque_masques,y
        sta droits_roque
        rts
+       dey
        bpl mr_boucle
        rts

; ---------------------------------------------------------------------
;  annuler_interne : defait le dernier coup empile
; ---------------------------------------------------------------------
annuler_interne
        lda nb_demi_coups
        bne +
        dec nb_demi_hi
+       dec nb_demi_coups
        jsr pos_hist
        ldy #0
        lda (ptr_hist),y
        sta cp_depart
        iny
        lda (ptr_hist),y
        sta cp_arrivee
        iny
        lda (ptr_hist),y
        sta cp_piece
        iny
        lda (ptr_hist),y
        sta cp_prise
        iny
        lda (ptr_hist),y
        sta droits_roque
        iny
        lda (ptr_hist),y
        sta case_ep
        iny
        lda (ptr_hist),y
        sta demi_50
        iny
        lda (ptr_hist),y
        sta cp_drapeau
        ; le trait revient au camp qui avait joue
        lda trait
        eor #NOIR
        sta trait
        ; la piece reprend sa case de depart, telle qu'elle etait avant
        ; une eventuelle promotion
        ldx cp_depart
        lda cp_piece
        sta plateau,x
        ldx cp_arrivee
        lda #VIDE
        sta plateau,x
        ; la piece prise revient
        lda cp_drapeau
        cmp #CP_EP
        beq ai_ep
        lda cp_prise
        beq ai_speciaux
        ldx cp_arrivee
        sta plateau,x
        jmp ai_speciaux
ai_ep
        jsr ji_case_pion_ep
        lda cp_prise
        sta plateau,x
ai_speciaux
        lda cp_drapeau
        cmp #CP_PETIT
        beq ai_petit
        cmp #CP_GRAND
        beq ai_grand
        jmp ai_roi
ai_petit
        ldx cp_arrivee      ; la tour revient de F en H
        dex
        lda plateau,x
        sta ji_tmp
        lda #VIDE
        sta plateau,x
        ldx cp_arrivee
        inx
        lda ji_tmp
        sta plateau,x
        jmp ai_roi
ai_grand
        lda cp_arrivee      ; la tour revient de D en A
        clc
        adc #1
        tax
        lda plateau,x
        sta ji_tmp
        lda #VIDE
        sta plateau,x
        lda cp_arrivee
        sec
        sbc #2
        tax
        lda ji_tmp
        sta plateau,x
ai_roi
        lda cp_piece
        and #MASQUE_TYPE
        cmp #ROI
        bne ai_fin
        lda cp_piece
        and #MASQUE_COUL
        lsr a
        lsr a
        lsr a
        tax
        lda cp_depart
        sta pos_roi,x
ai_fin
        rts

; ---------------------------------------------------------------------
;  coup_legal : joue le coup pointe par ptr_coup, regarde si le roi du
;  camp qui vient de jouer reste en prise, puis annule.
;  Sortie  C = 1 si le coup est legal
; ---------------------------------------------------------------------
coup_legal
        jsr charger_coup
        jsr jouer_interne
        jsr echec_apres_coup
        php
        jsr annuler_interne
        pla
        eor #1              ; le bit 0 du registre d'etat est la retenue
        pha
        plp
        rts

; echec_apres_coup : le camp qui vient de jouer laisse-t-il son roi en
; prise ? Sortie C = 1 si oui.
echec_apres_coup
        lda trait
        eor #NOIR
        jmp roi_en_echec

; ---------------------------------------------------------------------
;  filtrer_legaux : ne garde que les coups legaux de la tranche
;  Entree  ptr_liste = debut, coups_fin = fin
;  Sortie  coups_fin recule sur la nouvelle fin, gc_nb = coups gardes
; ---------------------------------------------------------------------
filtrer_legaux
        lda ptr_liste
        sta ptr_coup
        sta ptr_ecrit
        lda ptr_liste+1
        sta ptr_coup+1
        sta ptr_ecrit+1
        lda #0
        sta gc_nb
fl_boucle
        lda ptr_coup
        cmp coups_fin
        bne +
        lda ptr_coup+1
        cmp coups_fin+1
        beq fl_fin
+       jsr coup_legal
        bcc fl_suivant
        ; coup garde : on le recopie au debut de la place libre
        ldy #COUP_OCTETS-1
-       lda (ptr_coup),y
        sta (ptr_ecrit),y
        dey
        bpl -
        lda ptr_ecrit
        clc
        adc #COUP_OCTETS
        sta ptr_ecrit
        bcc +
        inc ptr_ecrit+1
+       inc gc_nb
fl_suivant
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc fl_boucle
        inc ptr_coup+1
        jmp fl_boucle
fl_fin
        lda ptr_ecrit
        sta coups_fin
        lda ptr_ecrit+1
        sta coups_fin+1
        rts

; ---------------------------------------------------------------------
;  generer_legaux : la liste des seuls coups legaux du camp au trait
;  Entree  coups_fin = debut de la tranche
;  Sortie  ptr_liste = debut, coups_fin = fin, gc_nb = nombre de coups
; ---------------------------------------------------------------------
generer_legaux
        lda coups_fin
        sta ptr_liste
        lda coups_fin+1
        sta ptr_liste+1
        jsr generer_coups
        jmp filtrer_legaux

; ---------------------------------------------------------------------
;  perft : compte les positions atteintes a la profondeur pf_prof
;  Le total s'accumule dans pf_nb, sur 32 bits. Routine recursive : elle
;  garde par niveau le debut, le courant et la fin de sa tranche de
;  coups, dans des tableaux indexes par pf_niv.
; ---------------------------------------------------------------------
perft
        lda pf_prof
        bne pf_descendre
        ; feuille : une position de plus
        inc pf_nb
        bne pf_feuille_fin
        inc pf_nb+1
        bne pf_feuille_fin
        inc pf_nb+2
        bne pf_feuille_fin
        inc pf_nb+3
pf_feuille_fin
        rts
pf_descendre
        ldx pf_niv
        lda coups_fin
        sta pf_deb_lo,x
        sta pf_cur_lo,x
        lda coups_fin+1
        sta pf_deb_hi,x
        sta pf_cur_hi,x
        jsr generer_coups
        ldx pf_niv
        lda coups_fin
        sta pf_fin_lo,x
        lda coups_fin+1
        sta pf_fin_hi,x
pf_boucle
        ldx pf_niv
        lda pf_cur_lo,x
        cmp pf_fin_lo,x
        bne pf_coup
        lda pf_cur_hi,x
        cmp pf_fin_hi,x
        beq pf_fin
pf_coup
        lda pf_cur_lo,x
        sta ptr_coup
        lda pf_cur_hi,x
        sta ptr_coup+1
        jsr charger_coup
        jsr jouer_interne
        jsr echec_apres_coup
        bcs pf_annuler      ; le roi restait en prise : coup illegal
        dec pf_prof
        inc pf_niv
        jsr perft
        dec pf_niv
        inc pf_prof
pf_annuler
        jsr annuler_interne
        ldx pf_niv
        lda pf_cur_lo,x
        clc
        adc #COUP_OCTETS
        sta pf_cur_lo,x
        bcc pf_boucle
        inc pf_cur_hi,x
        jmp pf_boucle
pf_fin
        ; la tranche de ce niveau est rendue
        lda pf_deb_lo,x
        sta coups_fin
        lda pf_deb_hi,x
        sta coups_fin+1
        rts
