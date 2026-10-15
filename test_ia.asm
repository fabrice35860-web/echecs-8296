; =====================================================================
;  test_ia.asm - ce que l'adversaire trouve sur des positions tranchees
;
;  Meme principe que perft.asm : on reprend du jeu le strict necessaire
;  (constantes, coups, evaluation, recherche) et on se passe de l'ecran
;  du jeu. Pour chaque position de donnees_ia.asm, le programme lance la
;  recherche au niveau demande et ecrit le coup trouve :
;
;      1 A1-A8
;
;  outils/test_ia.py compare a la liste des coups acceptables. Une
;  position mal jouee signale un defaut de la recherche ou de
;  l'evaluation, pas du generateur de coups : celui-la, perft le juge.
;
;  Assemblage :  64tass --cbm-prg -o test_ia.prg test_ia.asm
; =====================================================================

        * = $0401

        .word ligne_fin, 10
        .byte $9E           ; SYS
        .text "1040"
        .byte 0
ligne_fin
        .word 0

        * = $0410

debut
        lda #PET_EFFACER
        jsr CHROUT
        lda #0
        sta pos_index
boucle_positions
        jsr charger_position
        lda pos_index
        clc
        adc #1
        ora #'0'
        jsr CHROUT
        lda #' '
        jsr CHROUT
        lda #0
        sta pf_nb
        sta pf_nb+1
        sta pf_nb+2
        sta pf_nb+3
        jsr chercher_coup
        bcs tia_coup
        lda #<t_aucun
        ldx #>t_aucun
        jsr ecrire_texte
        jmp tia_ligne
tia_coup
        lda cp_depart
        jsr ecrire_case
        lda #'-'
        jsr CHROUT
        lda cp_arrivee
        jsr ecrire_case
        ; score retenu et noeuds visites, pour la mise au point
        lda #' '
        jsr CHROUT
        lda rc_score_iter+1
        bpl +
        lda #'-'
        jsr CHROUT
        sec
        lda #0
        sbc rc_score_iter
        sta nb32
        lda #0
        sbc rc_score_iter+1
        sta nb32+1
        jmp ++
+       lda rc_score_iter
        sta nb32
        lda rc_score_iter+1
        sta nb32+1
+       lda #0
        sta nb32+2
        sta nb32+3
        jsr ecrire_nb32
        lda #' '
        jsr CHROUT
        ldx #3
-       lda pf_nb,x
        sta nb32,x
        dex
        bpl -
        jsr ecrire_nb32
        ; profondeur menee a terme : c'est elle qui dit la force
        lda #' '
        jsr CHROUT
        lda #'P'
        jsr CHROUT
        lda rc_prof_faite
        sta nb32
        lda #0
        sta nb32+1
        sta nb32+2
        sta nb32+3
        jsr ecrire_nb32
tia_ligne
        lda #$0D
        jsr CHROUT
        inc pos_index
        lda pos_index
        cmp #IA_NB
        bcs +
        jmp boucle_positions
+       lda #<t_fini
        ldx #>t_fini
        jsr ecrire_texte
        rts

t_fini  .text "FINI"
        .byte $0D, 0
t_aucun .text "AUCUN"
        .byte 0

; ---------------------------------------------------------------------
;  ecrire_case : "E2" pour l'index 0x88 de A
; ---------------------------------------------------------------------
ecrire_case
        pha
        and #7
        clc
        adc #'A'
        jsr CHROUT
        pla
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #'1'
        jmp CHROUT

; ---------------------------------------------------------------------
;  ecrire_texte : chaine PETSCII terminee par zero, adresse A/X
; ---------------------------------------------------------------------
ecrire_texte
        sta ptr_texte
        stx ptr_texte+1
        ldy #0
et_boucle
        lda (ptr_texte),y
        beq et_fin
        jsr CHROUT
        iny
        bne et_boucle
et_fin
        rts

; ---------------------------------------------------------------------
;  charger_position : installe la position numero pos_index
; ---------------------------------------------------------------------
charger_position
        lda #VIDE
        ldx #0
-       sta plateau,x
        inx
        bpl -
        lda #0
        sta ptr_aux+1
        lda pos_index
        .for n = 0, n < 6, n = n + 1
        asl a
        rol ptr_aux+1
        .endfor
        clc
        adc #<ia_plateaux
        sta ptr_aux
        lda ptr_aux+1
        adc #>ia_plateaux
        sta ptr_aux+1
        ldy #0
        ldx #0
cp_boucle
        lda (ptr_aux),y
        sta plateau,x
        iny
        inx
        txa
        and #7
        bne cp_boucle
        txa
        clc
        adc #8
        tax
        cpy #64
        bcc cp_boucle
        ldx pos_index
        lda ia_traits,x
        sta trait
        lda ia_roques,x
        sta droits_roque
        lda ia_ep,x
        sta case_ep
        lda ia_niveaux,x
        sta niveau
        lda #0
        sta demi_50
        sta nb_demi_coups
        sta nb_demi_hi
        sta partie_finie
        lda #ORDI_AUCUN
        sta camp_ordi
        ldx #0
cpr_boucle
        txa
        and #HORS_ECH
        bne cpr_suivant
        lda plateau,x
        and #MASQUE_TYPE
        cmp #ROI
        bne cpr_suivant
        lda plateau,x
        and #MASQUE_COUL
        lsr a
        lsr a
        lsr a
        tay
        txa
        sta pos_roi,y
cpr_suivant
        inx
        bpl cpr_boucle
        rts

; ---------------------------------------------------------------------
;  afficher_reflexion : le jeu l'utilise pour tenir le joueur au
;  courant ; ici il n'y a pas de panneau, et rien a dire.
; ---------------------------------------------------------------------
afficher_reflexion
        rts

pos_index       .byte 0
nb32            .byte 0, 0, 0, 0
reste           .byte 0, 0, 0, 0
chiffre         .byte 0
significatif    .byte 0

; ---------------------------------------------------------------------
;  ecrire_nb32 : nb32 en decimal, sans zero de tete
; ---------------------------------------------------------------------
ecrire_nb32
        lda #0
        sta significatif
        ldx #0
en_rang
        lda #0
        sta chiffre
en_sous
        sec
        lda nb32
        sbc puis10_0,x
        sta reste
        lda nb32+1
        sbc puis10_1,x
        sta reste+1
        lda nb32+2
        sbc puis10_2,x
        sta reste+2
        lda nb32+3
        sbc puis10_3,x
        sta reste+3
        bcc en_rang_fini
        ldy #3
-       lda reste,y
        sta nb32,y
        dey
        bpl -
        inc chiffre
        jmp en_sous
en_rang_fini
        cpx #9
        beq en_emettre
        lda chiffre
        bne en_emettre
        lda significatif
        beq en_suivant
en_emettre
        lda #1
        sta significatif
        lda chiffre
        clc
        adc #'0'
        jsr CHROUT
en_suivant
        inx
        cpx #10
        bcc en_rang
        rts

puis10_0
        .byte $00, $00, $00, $40, $A0, $10, $E8, $64, $0A, $01
puis10_1
        .byte $CA, $E1, $96, $42, $86, $27, $03, $00, $00, $00
puis10_2
        .byte $9A, $F5, $98, $0F, $01, $00, $00, $00, $00, $00
puis10_3
        .byte $3B, $05, $00, $00, $00, $00, $00, $00, $00, $00

; ---------------------------------------------------------------------
;  Sources communes avec le jeu
; ---------------------------------------------------------------------
        .include "constantes.asm"
        .include "coups.asm"
        .include "evaluation.asm"
        .include "recherche.asm"
        .include "donnees_regles.asm"
        .include "donnees_eval.asm"
        .include "donnees_ia.asm"

        .cerror * > DEBUT_ZONES, "test_ia.prg deborde sur les zones de travail"
