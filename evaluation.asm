; =====================================================================
;  evaluation.asm - ce que vaut une position pour le camp au trait
;
;  Le score est en centipions, sur seize bits signes, et toujours rendu
;  du point de vue du camp au trait : c'est ce qu'attend la recherche
;  negamax. Il additionne la valeur des pieces, leur placement (tables de
;  donnees_eval.asm), et une appreciation simple de la structure de
;  pions. Le roi est juge sur deux tables : au milieu de partie il se
;  cache derriere ses pions, en finale il doit marcher vers le centre.
; =====================================================================

; ---------------------------------------------------------------------
;  evaluer : remplit ev_score
; ---------------------------------------------------------------------
evaluer
        lda #0
        sta ev_score
        sta ev_score+1
        sta ev_mat
        sta ev_mat+1
        ldx #7
-       sta ev_pions_b,x
        sta ev_pions_n,x
        dex
        bpl -
        ldx #0
ev_boucle
        txa
        and #HORS_ECH
        bne ev_suivant
        lda plateau,x
        beq ev_suivant
        sta ev_piece
        and #MASQUE_TYPE
        cmp #ROI
        beq ev_suivant      ; les deux rois sont comptes a part
        sta ev_type
        cmp #PION
        bne ev_valeur
        ; un pion de plus sur sa colonne
        stx ev_case
        txa
        and #7
        tax
        lda ev_piece
        and #MASQUE_COUL
        bne ev_pion_noir
        inc ev_pions_b,x
        jmp ev_pion_fin
ev_pion_noir
        inc ev_pions_n,x
ev_pion_fin
        ldx ev_case
ev_valeur
        ldy ev_type
        lda valeurs_lo,y
        sta ev_tmp
        lda valeurs_hi,y
        sta ev_tmp+1
        ; la matiere hors pions dit quand la finale commence
        cpy #PION
        beq ev_position
        lda ev_mat
        clc
        adc ev_tmp
        sta ev_mat
        lda ev_mat+1
        adc ev_tmp+1
        sta ev_mat+1
ev_position
        lda eval_tables_lo,y
        sta ptr_eval
        lda eval_tables_hi,y
        sta ptr_eval+1
        jsr ev_bonus_case
        lda ev_piece
        and #MASQUE_COUL
        bne ev_retirer
        jsr ev_ajouter
        jmp ev_suivant
ev_retirer
        jsr ev_soustraire
ev_suivant
        inx
        bpl ev_boucle

        ; --- les deux rois ---
        lda ev_mat+1
        cmp #>SEUIL_FINALE
        bcc ev_finale
        bne ev_milieu
        lda ev_mat
        cmp #<SEUIL_FINALE
        bcs ev_milieu
ev_finale
        lda #<eval_roi_finale
        sta ptr_eval
        lda #>eval_roi_finale
        sta ptr_eval+1
        jmp ev_rois
ev_milieu
        lda #<eval_roi
        sta ptr_eval
        lda #>eval_roi
        sta ptr_eval+1
ev_rois
        lda #0
        sta ev_tmp
        sta ev_tmp+1
        ldx pos_roi
        lda #BLANC
        sta ev_piece
        jsr ev_bonus_case
        jsr ev_ajouter
        lda #0
        sta ev_tmp
        sta ev_tmp+1
        ldx pos_roi+1
        lda #NOIR
        sta ev_piece
        jsr ev_bonus_case
        jsr ev_soustraire

        jsr ev_structure

        ; --- le score se lit du point de vue du camp au trait ---
        lda trait
        beq ev_fin
        sec
        lda #0
        sbc ev_score
        sta ev_score
        lda #0
        sbc ev_score+1
        sta ev_score+1
ev_fin
        rts

; ---------------------------------------------------------------------
;  ev_bonus_case : ajoute a ev_tmp la valeur que la table ptr_eval donne
;  a la case X. Les Noirs lisent la table retournee : case EOR $70.
; ---------------------------------------------------------------------
ev_bonus_case
        txa
        ldy ev_piece
        cpy #NOIR
        bcc +
        eor #$70
+       tay
        lda (ptr_eval),y
        ldy #0
        cmp #$80
        bcc +
        ldy #$FF            ; valeur negative : le poids fort suit
+       clc
        adc ev_tmp
        sta ev_tmp
        tya
        adc ev_tmp+1
        sta ev_tmp+1
        rts

; ev_ajouter / ev_soustraire : ev_score = ev_score +/- ev_tmp
ev_ajouter
        clc
        lda ev_score
        adc ev_tmp
        sta ev_score
        lda ev_score+1
        adc ev_tmp+1
        sta ev_score+1
        rts

ev_soustraire
        sec
        lda ev_score
        sbc ev_tmp
        sta ev_score
        lda ev_score+1
        sbc ev_tmp+1
        sta ev_score+1
        rts

; ---------------------------------------------------------------------
;  ev_structure : pions doubles et pions isoles
;
;  Deux pions sur la meme colonne se genent ; un pion sans voisin sur les
;  colonnes d'a cote ne sera jamais defendu par un pion. C'est la
;  "structure de pions simple" que demande CLAUDE.md : de quoi eviter les
;  pires maladresses sans ralentir la recherche.
; ---------------------------------------------------------------------
ev_structure
        ldy #7
evs_colonne
        sty ev_colonne
        ; --- les Blancs ---
        lda ev_pions_b,y
        beq evs_noirs
        sta ev_nb
        jsr evs_malus       ; ev_tmp = malus de cette colonne
        jsr ev_soustraire   ; un malus se retire du score des Blancs
evs_noirs
        ldy ev_colonne
        lda ev_pions_n,y
        beq evs_suivante
        sta ev_nb
        jsr evs_malus_n
        jsr ev_ajouter      ; un malus noir profite aux Blancs
evs_suivante
        ldy ev_colonne
        dey
        bpl evs_colonne
        rts

; evs_malus : malus (positif) de la colonne ev_colonne pour les Blancs
evs_malus
        lda #0
        sta ev_tmp
        sta ev_tmp+1
        lda ev_nb
        sec
        sbc #1
        beq +
        ldx #MALUS_DOUBLE   ; (n - 1) fois le malus du pion double
        jsr evs_multiplier
+       ; isole ?
        ldy ev_colonne
        jsr evs_voisins_b
        bcs evs_malus_fin
        lda ev_tmp
        clc
        adc #MALUS_ISOLE
        sta ev_tmp
        bcc evs_malus_fin
        inc ev_tmp+1
evs_malus_fin
        rts

evs_malus_n
        lda #0
        sta ev_tmp
        sta ev_tmp+1
        lda ev_nb
        sec
        sbc #1
        beq +
        ldx #MALUS_DOUBLE
        jsr evs_multiplier
+       ldy ev_colonne
        jsr evs_voisins_n
        bcs evs_malus_n_fin
        lda ev_tmp
        clc
        adc #MALUS_ISOLE
        sta ev_tmp
        bcc evs_malus_n_fin
        inc ev_tmp+1
evs_malus_n_fin
        rts

; evs_multiplier : ev_tmp += A * X, A et X petits
evs_multiplier
        tay
        beq evs_mul_fin
evs_mul_boucle
        txa
        clc
        adc ev_tmp
        sta ev_tmp
        bcc +
        inc ev_tmp+1
+       dey
        bne evs_mul_boucle
evs_mul_fin
        rts

; evs_voisins_b / evs_voisins_n : y a-t-il un pion ami sur une colonne
; voisine de Y ? Sortie C = 1 si oui.
evs_voisins_b
        dey
        bmi +
        lda ev_pions_b,y
        bne evs_voisin_oui
+       ldy ev_colonne
        iny
        cpy #8
        bcs evs_voisin_non
        lda ev_pions_b,y
        bne evs_voisin_oui
evs_voisin_non
        clc
        rts
evs_voisin_oui
        sec
        rts

evs_voisins_n
        dey
        bmi +
        lda ev_pions_n,y
        bne evs_voisin_oui
+       ldy ev_colonne
        iny
        cpy #8
        bcs evs_voisin_non
        lda ev_pions_n,y
        bne evs_voisin_oui
        beq evs_voisin_non
