; =====================================================================
;  ecran_rom.asm - choix du jeu de caracteres de la machine
;
;  Le generateur de caracteres de la machine du proprietaire est une EPROM
;  francaise (AZ-E-01 GEN.) : ses formes graphiques n'ont pas les memes
;  codes que la ROM standard, et en mode graphique elle n'a pas les quarts
;  de bloc dont les pieces sont faites. Comme on ne peut pas deviner a coup
;  sur, on montre un echantillon de chaque et on laisse choisir.
;
;  Les deux echantillons sont donc tres differents : a gauche des pieces
;  dessinees en quarts de bloc, a droite le repli "lettre encadree".
; =====================================================================

; Trois echantillons de douze colonnes, repartis sur la largeur
ROM_COL_1   = 5             ; ROM standard
ROM_COL_2   = 33            ; ROM EDEX
ROM_COL_3   = 61            ; repli "lettre encadree"
ROM_L_TITRE = 7             ; ligne des libelles
ROM_L_ECH   = 9             ; premiere ligne des echantillons

; ---------------------------------------------------------------------
;  appliquer_rom : remplit les variables de forme depuis le prereglage
;  Les variables commutables se suivent en memoire, dans l'ordre du
;  prereglage : une simple recopie suffit.
; ---------------------------------------------------------------------
appliquer_rom
        ldx rom_choisie
        lda prereglages_lo,x
        ldy prereglages_hi,x
        sta ptr_aux
        sty ptr_aux+1
        jmp ar_copier2
ar_copier
ar_copier2
        ldy #0
-       lda (ptr_aux),y
        sta car_quarts,y
        iny
        cpy #NB_CAR_TOTAL
        bne -
        rts

; ---------------------------------------------------------------------
;  detecter_rom : preselectionne un prereglage
;
;  On fait la somme sur 16 bits de toute la ROM de l'editeur ($E000-$E7FF)
;  et on la compare aux empreintes des editeurs standard connus. Celles des
;  versions 50 Hz et 60 Hz se trouvent etre identiques ($528A), ce qui rend
;  la reconnaissance robuste ; VICE charge une variante dont la somme vaut
;  $52AE, egalement admise. Toute autre somme est tenue pour une EPROM
;  francaise, ce qui est le defaut voulu : au pire le joueur corrige d'une
;  touche.
; ---------------------------------------------------------------------
detecter_rom
        lda #0
        sta som_lo
        sta som_hi
        sta ptr_aux
        lda #$E0
        sta ptr_aux+1
        ldx #8              ; huit pages de 256 octets
dr_page
        ldy #0
dr_octet
        lda (ptr_aux),y
        clc
        adc som_lo
        sta som_lo
        bcc +
        inc som_hi
+       iny
        bne dr_octet
        inc ptr_aux+1
        dex
        bne dr_page
        ldx #0
dr_compare
        lda som_lo
        cmp empreintes_lo,x
        bne dr_suivante
        lda som_hi
        cmp empreintes_hi,x
        bne dr_suivante
        lda #0              ; editeur standard reconnu
        sta rom_choisie
        rts
dr_suivante
        inx
        cpx #NB_EMPREINTES
        bne dr_compare
        lda #1              ; inconnu : on presume l'EPROM francaise
        sta rom_choisie
        rts

; ---------------------------------------------------------------------
;  choix_rom : l'ecran de selection. Rend la main sur RETURN.
;  Les libelles n'emploient que des lettres sans accent, communes aux deux
;  ROM : il faut pouvoir les lire avant d'avoir choisi.
; ---------------------------------------------------------------------
choix_rom
        lda #MODE_GRAPH
        sta REG_CARACT
        jsr effacer_ecran
        lda #LIG_TITRE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #LARGEUR
        jsr remplir
        lda #<rom_textes
        sta ptr_aux
        lda #>rom_textes
        sta ptr_aux+1
        jsr afficher_table
        ; un echantillon par prereglage, chacun trace avec le sien
        ldx #0
cr_echantillon
        stx rom_choisie
        jsr appliquer_rom
        ldx rom_choisie
        lda rom_colonnes,x
        sta ech_colonne
        txa
        pha
        jsr echantillon
        pla
        tax
        inx
        cpx #NB_ROMS
        bne cr_echantillon
        ; retablit la preselection
        jsr detecter_rom
        jsr appliquer_rom
cr_boucle
        jsr marquer_choix
cr_touche
        jsr GETIN
        beq cr_touche
        cmp #TOUCHE_RET
        beq cr_valider
        cmp #TOUCHE_ESP
        beq cr_valider
        cmp #$31            ; "1"
        bcc cr_touche
        cmp #$30+NB_ROMS+1
        bcs cr_touche
        sec
        sbc #$31
        sta rom_choisie
        jsr appliquer_rom
        jmp cr_boucle
cr_valider
        rts

; ---------------------------------------------------------------------
;  marquer_choix : met en video inverse le libelle retenu
; ---------------------------------------------------------------------
marquer_choix
        ldx #0
mc_boucle
        stx tmp_index
        ; le libelle du choix retenu passe en video inverse
        lda #0
        cpx rom_choisie
        bne +
        lda #INVERSE
+       sta attr_texte
        ldx tmp_index
        lda rom_lignes,x
        sta tmp_ligne
        lda rom_colonnes,x
        sta tmp_colonne
        lda rom_libelles_hi,x
        sta pz_tmp
        lda rom_libelles_lo,x
        ldx pz_tmp
        jsr afficher_en
        ldx tmp_index
        inx
        cpx #NB_ROMS
        bne mc_boucle
        lda #0
        sta attr_texte
        rts

; ---------------------------------------------------------------------
;  echantillon : un petit echiquier de deux cases sur deux, trace avec le
;  prereglage actif, a la colonne ech_colonne
; ---------------------------------------------------------------------
echantillon
        ldx #0
ech_boucle
        lda ech_defs,x
        cmp #$FF
        beq ech_fin
        clc
        adc #ROM_L_ECH
        sta tmp_ligne
        inx
        lda ech_defs,x
        clc
        adc ech_colonne
        sta tmp_colonne
        inx
        lda ech_defs,x
        sta pz_tmp3         ; fond : 0 = case foncee, 1 = case claire
        inx
        lda ech_defs,x
        sta pz_tmp4         ; piece a poser
        inx
        stx tmp_index
        ; fond de la case
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        lda #0
        sta attr_case
        lda pz_tmp3
        beq +
        lda car_damier
        jmp ++
+       lda #CAR_ESPACE
+       ldy #CASE_L-1
-       sta (ptr_ecran),y
        dey
        bpl -
        ldy #LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #LARGEUR-1
        bne -
        ldy #2*LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #2*LARGEUR-1
        bne -
        lda pz_tmp4
        jsr dessiner_piece
        ldx tmp_index
        jmp ech_boucle
ech_fin
        rts
