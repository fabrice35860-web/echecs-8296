; =====================================================================
;  perft.asm - validation du generateur de coups sur la vraie machine
;
;  Programme a part, qui ne reprend du jeu que constantes.asm,
;  donnees_regles.asm et coups.asm : ni ecran, ni clavier, ni regles
;  d'interface. Il compte les positions atteintes a chaque profondeur
;  pour cinq positions de reference et ecrit une ligne par position :
;
;      1 20 400 8902 197281
;
;  Les nombres attendus viennent de python-chess (outils/generer_perft.py)
;  et la comparaison se fait dans outils/test_perft.py. Un ecart signale
;  toujours un defaut du generateur : roque, prise en passant, promotion
;  ou coup qui laisse son roi en prise.
;
;  Assemblage :  64tass --cbm-prg -o perft.prg perft.asm
; =====================================================================

        * = $0401

; --- amorce BASIC : 10 SYS1040 ---------------------------------------
        .word ligne_fin, 10
        .byte $9E           ; SYS
        .text "1040"
        .byte 0
ligne_fin
        .word 0

        * = $0410

; ---------------------------------------------------------------------
;  Programme principal
; ---------------------------------------------------------------------
debut
        lda #PET_EFFACER
        jsr CHROUT
        lda #0
        sta pos_index
boucle_positions
        jsr charger_position
        ; numero de la position, puis ses comptes
        lda pos_index
        clc
        adc #1
        sta nb32
        lda #0
        sta nb32+1
        sta nb32+2
        sta nb32+3
        jsr ecrire_nb32
        lda #1
        sta prof_courante
boucle_profondeur
        ldx pos_index
        lda perft_profondeurs,x
        cmp prof_courante
        bcc fin_position
        jsr un_perft
        lda #' '
        jsr CHROUT
        jsr ecrire_nb32
        inc prof_courante
        jmp boucle_profondeur
fin_position
        lda #$0D
        jsr CHROUT
        inc pos_index
        lda pos_index
        cmp #PERFT_NB
        bcc boucle_positions
        ; marqueur de fin : le test sait que rien n'a ete interrompu
        lda #<t_fini
        ldx #>t_fini
        jsr ecrire_texte
        rts

t_fini  .text "FINI"
        .byte $0D, 0

; ---------------------------------------------------------------------
;  un_perft : compte les positions a la profondeur prof_courante
;  Sortie  nb32 = total
; ---------------------------------------------------------------------
un_perft
        jsr charger_position        ; on repart toujours de la position
        lda #0
        sta pf_nb
        sta pf_nb+1
        sta pf_nb+2
        sta pf_nb+3
        sta pf_niv
        lda prof_courante
        sta pf_prof
        lda #<coups_zone
        sta coups_fin
        lda #>coups_zone
        sta coups_fin+1
        jsr perft
        ldx #3
-       lda pf_nb,x
        sta nb32,x
        dex
        bpl -
        rts

; ---------------------------------------------------------------------
;  charger_position : installe la position numero pos_index
; ---------------------------------------------------------------------
charger_position
        ; plateau entierement vide, cases fictives comprises
        lda #VIDE
        ldx #0
-       sta plateau,x
        inx
        bpl -
        ; adresse des 64 cases : perft_plateaux + 64 * pos_index
        lda #0
        sta ptr_aux+1
        lda pos_index
        .for n = 0, n < 6, n = n + 1
        asl a
        rol ptr_aux+1
        .endfor
        clc
        adc #<perft_plateaux
        sta ptr_aux
        lda ptr_aux+1
        adc #>perft_plateaux
        sta ptr_aux+1
        ; recopie, rangee par rangee : les 64 octets sont compacts, le
        ; plateau 0x88 laisse huit cases fictives au bout de chaque rangee
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
        ; etat annexe
        ldx pos_index
        lda perft_traits,x
        sta trait
        lda perft_roques,x
        sta droits_roque
        lda perft_ep,x
        sta case_ep
        lda #0
        sta demi_50
        sta nb_demi_coups
        sta nb_demi_hi
        ; position des deux rois
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
;  ecrire_nb32 : ecrit nb32 en decimal, sans zero de tete
;  Soustractions successives des puissances de dix ; nb32 est consomme.
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
        beq en_emettre      ; le rang des unites s'ecrit toujours
        lda chiffre
        bne en_emettre
        lda significatif
        beq en_suivant      ; zero de tete : on le tait
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

; Les dix puissances de dix, eclatees en quatre tables pour un acces
; indexe simple.
puis10_0
        .byte $00, $00, $00, $40, $A0, $10, $E8, $64, $0A, $01
puis10_1
        .byte $CA, $E1, $96, $42, $86, $27, $03, $00, $00, $00
puis10_2
        .byte $9A, $F5, $98, $0F, $01, $00, $00, $00, $00, $00
puis10_3
        .byte $3B, $05, $00, $00, $00, $00, $00, $00, $00, $00

; ---------------------------------------------------------------------
;  Variables propres a ce programme
; ---------------------------------------------------------------------
pos_index       .byte 0
prof_courante   .byte 0
nb32            .byte 0, 0, 0, 0
reste           .byte 0, 0, 0, 0
chiffre         .byte 0
significatif    .byte 0

; ---------------------------------------------------------------------
;  Sources communes avec le jeu
; ---------------------------------------------------------------------
        .include "constantes.asm"
        .include "coups.asm"
        .include "donnees_regles.asm"
        .include "donnees_perft.asm"

        .cerror * > DEBUT_ZONES, "perft.prg deborde sur les zones de travail"
