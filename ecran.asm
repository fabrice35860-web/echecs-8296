; =====================================================================
;  ecran.asm - affichage de l'echiquier, des pieces et du panneau
; =====================================================================

; ---------------------------------------------------------------------
;  init_ecran : passe en majuscules + graphiques et efface tout l'ecran
; ---------------------------------------------------------------------
init_ecran
        lda #MODE_GRAPH
        sta REG_CARACT
        ; fallthrough

; ---------------------------------------------------------------------
;  effacer_ecran : remplit la RAM ecran d'espaces
;  On ecrit les 2048 octets de la RAM ecran (les 48 derniers ne sont pas
;  affiches, cela evite un comptage sur 16 bits).
; ---------------------------------------------------------------------
effacer_ecran
        lda #CAR_ESPACE
        ldx #0
-       sta ECRAN+$000,x
        sta ECRAN+$100,x
        sta ECRAN+$200,x
        sta ECRAN+$300,x
        sta ECRAN+$400,x
        sta ECRAN+$500,x
        sta ECRAN+$600,x
        sta ECRAN+$700,x
        inx
        bne -
        rts

; ---------------------------------------------------------------------
;  pos_ecran : calcule l'adresse ecran d'une position
;  Entree  A = ligne (0..24), X = colonne (0..79)
;  Sortie  ptr_ecran pointe ce caractere. A et Y sont detruits.
; ---------------------------------------------------------------------
pos_ecran
        tay
        txa
        clc
        adc lignes_lo,y
        sta ptr_ecran
        lda lignes_hi,y
        adc #0
        sta ptr_ecran+1
        rts

; ---------------------------------------------------------------------
;  remplir : ecrit X fois le caractere A a partir de ptr_ecran
;  Entree  A = caractere, X = nombre (1..255)
; ---------------------------------------------------------------------
remplir
        ldy #0
-       sta (ptr_ecran),y
        iny
        dex
        bne -
        rts

; ---------------------------------------------------------------------
;  effacer_ligne : remplit la ligne A d'espaces, sur toute sa largeur
; ---------------------------------------------------------------------
effacer_ligne
        ldx #0
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #LARGEUR
        jmp remplir

; ---------------------------------------------------------------------
;  effacer_panneau_ligne : efface la ligne A dans le seul panneau
;  L'echiquier occupe les colonnes 0 a 49 : il ne faut pas y toucher.
; ---------------------------------------------------------------------
effacer_panneau_ligne
        ldx #PAN_X
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #PAN_L
        jmp remplir

; ---------------------------------------------------------------------
;  afficher_texte : copie la chaine pointee par ptr_texte vers ptr_ecran
;  La chaine est en codes ecran et se termine par 0.
;  attr_texte ($00 ou $80) est combine a chaque caractere.
; ---------------------------------------------------------------------
afficher_texte
        ldy #0
at_car
        lda (ptr_texte),y
        beq at_fini
        ; un marqueur d'accent prend la forme que lui donne la ROM active
        cmp #ACC_E_AIGU
        bcc at_pose
        cmp #ACC_C_CEDIL+1
        bcs at_pose
        sty sauve_y
        sec
        sbc #ACC_E_AIGU
        tay
        lda accents,y
        ldy sauve_y
at_pose
        ora attr_texte
        sta (ptr_ecran),y
        iny
        bne at_car
at_fini
        rts

; ---------------------------------------------------------------------
;  avancer_ecran : ptr_ecran avance de Y caracteres, et Y repart de zero
;  afficher_texte indexe la chaine ET l'ecran avec le meme Y : pour
;  enchainer deux textes il faut donc deplacer le pointeur, pas le Y.
; ---------------------------------------------------------------------
avancer_ecran
        tya
        clc
        adc ptr_ecran
        sta ptr_ecran
        bcc +
        inc ptr_ecran+1
+       ldy #0
        rts

; ---------------------------------------------------------------------
;  afficher_en : affiche le texte (A = poids faible, X = poids fort) en
;                (tmp_ligne, tmp_colonne), avec l'attribut attr_texte
; ---------------------------------------------------------------------
afficher_en
        sta ptr_texte
        stx ptr_texte+1
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        jmp afficher_texte

; ---------------------------------------------------------------------
;  afficher_table : affiche une suite de textes fixes
;  Entree  ptr_aux pointe une table d'entrees de 5 octets :
;          ligne, colonne, attribut, adresse (poids faible, poids fort)
;          La table se termine par l'octet $FF.
; ---------------------------------------------------------------------
afficher_table
        ldy #0
ata_boucle
        lda (ptr_aux),y
        cmp #$FF
        beq ata_fin
        sta tmp_ligne
        iny
        lda (ptr_aux),y
        sta tmp_colonne
        iny
        lda (ptr_aux),y
        sta attr_texte
        iny
        lda (ptr_aux),y
        sta ptr_texte
        iny
        lda (ptr_aux),y
        sta ptr_texte+1
        iny
        sty tmp_index
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        jsr afficher_texte
        ldy tmp_index
        bne ata_boucle      ; la table fait moins de 256 octets
ata_fin
        lda #0
        sta attr_texte
        rts

; ---------------------------------------------------------------------
;  pos_case : place ptr_ecran sur le coin haut-gauche de la case A
;  Entree  A = index 0x88 d'une case de l'echiquier
; ---------------------------------------------------------------------
pos_case
        tax
        lda case_adr_lo,x
        sta ptr_ecran
        lda case_adr_hi,x
        sta ptr_ecran+1
        rts

; ---------------------------------------------------------------------
;  dessiner_case : redessine entierement la case A
;  Entree  A = index 0x88
;
;  Fond : damier sur les cases claires, vide sur les cases foncees. Le
;  curseur se signale en inversant toute la case une phase de battement
;  sur deux ; la piece suit cette inversion, car le complement d'un quart
;  de bloc est exactement son inverse video : il suffit d'echanger les
;  tables des Blancs et des Noirs.
; ---------------------------------------------------------------------
dessiner_case
        sta case_courante
        jsr pos_case
        ; attribut de la case : inversion sous le curseur, une phase sur deux
        ldx #0
        lda case_courante
        cmp curseur
        bne dc_attr
        lda clign_phase
        beq dc_attr
        ldx #INVERSE
        ; une piece prenable bat elle aussi, pour se signaler
        lda selection
        bmi dc_attr
        lda clign_phase
        beq dc_attr
        ldy case_courante
        lda plateau,y
        beq dc_attr         ; case vide : elle aura son motif central
        lda case_courante
        jsr est_destination
        bcc dc_attr
        ldx #INVERSE
dc_attr
        stx attr_case
        ; Fond de la case, et caractere "oppose" dont se servent les
        ; marquages. Sous le curseur le fond devient un bloc plein au lieu
        ; du fond inverse : le damier inverse ressemble trop au damier, et
        ; le curseur se voyait a peine sur les cases claires.
        cpx #0
        beq dc_fond_repos
        lda #CAR_ESP_INV
        ldx #CAR_ESPACE
        jmp dc_fond
dc_fond_repos
        ldx case_courante
        lda case_claire,x
        beq dc_foncee
        lda car_damier
        jmp dc_oppose
dc_foncee
        lda #CAR_ESPACE
dc_oppose
        ldx #CAR_ESP_INV
dc_fond
        stx tmp_car_op
        sta tmp_car
        ; fond : les 6 colonnes des 3 lignes de la case
        ldy #CASE_L-1
-       sta (ptr_ecran),y
        dey
        bpl -
        lda tmp_car
        ldy #LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #LARGEUR-1
        bne -
        lda tmp_car
        ldy #2*LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #2*LARGEUR-1
        bne -
        ; piece choisie : les colonnes 0 et 5 passent en video opposee, ce
        ; qui encadre la piece de deux barres (effet de crochets). Marquage
        ; fixe, qui ne clignote pas de lui-meme.
        lda case_courante
        cmp selection
        bne dc_marques
        lda tmp_car_op
        ldy #0
        sta (ptr_ecran),y
        ldy #CASE_L-1
        sta (ptr_ecran),y
        ldy #LARGEUR
        sta (ptr_ecran),y
        ldy #LARGEUR+CASE_L-1
        sta (ptr_ecran),y
        ldy #2*LARGEUR
        sta (ptr_ecran),y
        ldy #2*LARGEUR+CASE_L-1
        sta (ptr_ecran),y
dc_marques
        ; contenu de la case
        ldx case_courante
        lda plateau,x
        bne dessiner_piece
        ; case vide : un petit bloc au centre si on peut s'y rendre
        lda selection
        bmi dc_rien
        lda case_courante
        jsr est_destination
        bcc dc_rien
        lda tmp_car_op
        ldy #LARGEUR+2
        sta (ptr_ecran),y
        ldy #LARGEUR+3
        sta (ptr_ecran),y
dc_rien
        rts

; ---------------------------------------------------------------------
;  marquer_destinations / effacer_destinations : les cases ou la piece
;  choisie peut se rendre. Elles sont simplement redessinees : c'est
;  dessiner_case qui sait les reconnaitre.
; ---------------------------------------------------------------------
marquer_destinations
        lda selection
        bpl cases_de_selection
        rts

effacer_destinations
        lda selection
        bmi efd_fin
        sta sel_prec
        lda #$FF
        sta selection       ; sans quoi le marquage se redessinerait
        lda sel_prec
        jmp cases_de_depart
efd_fin
        rts

cases_de_selection
        lda selection
cases_de_depart
        sta sel_prec
        jsr dessiner_case
        lda #<LISTE_PARTIE
        sta ptr_coup
        lda #>LISTE_PARTIE
        sta ptr_coup+1
        ldx nb_coups_partie
        beq cds_fin
cds_boucle
        ldy #0
        lda (ptr_coup),y
        cmp sel_prec
        bne cds_suivant
        iny
        lda (ptr_coup),y
        stx sauve_x
        jsr dessiner_case
        ldx sauve_x
cds_suivant
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc +
        inc ptr_coup+1
+       dex
        bne cds_boucle
cds_fin
        rts

; ---------------------------------------------------------------------
;  dessiner_piece : trace la piece A dans la case pointee par ptr_ecran
;  Entree  A = contenu de la case (type + bit de couleur)
;          ptr_ecran = coin haut-gauche de la case
;          attr_case = $80 si toute la case est en video inverse
;
;  Deux dessins possibles selon la ROM de caracteres :
;    - quarts de bloc : 12 caracteres precalcules (donnees_pieces.asm) ;
;    - repli "lettre encadree" quand la ROM n'a pas les quarts, la lettre
;      francaise de la piece dans un cadre arrondi de 3 x 3.
; ---------------------------------------------------------------------
dessiner_piece
        sta piece_courante
        lda pieces_graphiques
        beq dp_lettre

; --- pieces dessinees, quarts de bloc ou formes EDEX ------------------
        ; Les deux tables viennent du prereglage de la ROM : rien ne
        ; distingue ici les silhouettes en quarts de bloc des pieces EDEX,
        ; ce sont douze codes ecran a poser dans les deux cas.
        ; La table des Noirs porte l'inverse video de celle des Blancs :
        ; sous le curseur, qui inverse toute la case, on prend l'autre.
        lda piece_courante
        and #MASQUE_COUL
        beq +
        lda #INVERSE        ; une piece noire : video "inversee" au depart
+       eor attr_case
        beq dp_blanche
        lda ptr_pieces_n
        ldx ptr_pieces_n+1
        jmp +
dp_blanche
        lda ptr_pieces_b
        ldx ptr_pieces_b+1
+       sta ptr_piece
        stx ptr_piece+1
        ; index = (type - 1) * 12
        lda piece_courante
        and #MASQUE_TYPE
        sec
        sbc #1
        sta pz_tmp
        asl a               ; x2
        asl a               ; x4
        clc
        adc pz_tmp          ; x5
        adc pz_tmp          ; x6
        asl a               ; x12
        clc
        adc ptr_piece
        sta ptr_piece
        bcc +
        inc ptr_piece+1
+
        ; les 12 caracteres : 4 colonnes sur 3 lignes, a partir de PIECE_DX
        ldy #0
        ldx #PIECE_DX
        jsr dp_rangee
        ldx #LARGEUR+PIECE_DX
        jsr dp_rangee
        ldx #2*LARGEUR+PIECE_DX
        jmp dp_rangee

; pose quatre caracteres consecutifs a partir du decalage X
dp_rangee
        stx pz_tmp2
        ldx #4
-       lda (ptr_piece),y
        sty sauve_y
        ldy pz_tmp2
        sta (ptr_ecran),y
        inc pz_tmp2
        ldy sauve_y
        iny
        dex
        bne -
        rts

; --- repli "lettre encadree" -----------------------------------------
;     ,-.      le cadre et la lettre occupent les colonnes 1 a 3 de la
;     |R|      case ; une piece noire est le meme cadre en video inverse
;     `-'
dp_lettre
        lda piece_courante
        and #MASQUE_COUL
        beq +
        lda #INVERSE
+       eor attr_case
        sta attr_piece
        ; ligne du haut : arc, trait, arc
        ldy #LETTRE_DX
        lda car_arc_hg
        jsr dp_pose
        lda car_trait_h
        jsr dp_pose
        lda car_arc_hd
        jsr dp_pose
        ; ligne du milieu : montant, lettre, montant
        ldy #LARGEUR+LETTRE_DX
        lda car_trait_v
        jsr dp_pose
        lda piece_courante
        and #MASQUE_TYPE
        tax
        lda lettres_pieces-1,x
        jsr dp_pose
        lda car_trait_v
        jsr dp_pose
        ; ligne du bas : arc, trait, arc
        ldy #2*LARGEUR+LETTRE_DX
        lda car_arc_bg
        jsr dp_pose
        lda car_trait_h
        jsr dp_pose
        lda car_arc_bd
        jmp dp_pose

dp_pose
        ora attr_piece
        sta (ptr_ecran),y
        iny
        rts

; ---------------------------------------------------------------------
;  dessiner_echiquier : les 64 cases, puis les coordonnees
; ---------------------------------------------------------------------
dessiner_echiquier
        lda #0
        sta tmp_index       ; index 0x88 courant
de_boucle
        lda tmp_index
        and #HORS_ECH
        bne de_suivante
        lda tmp_index
        jsr dessiner_case
de_suivante
        inc tmp_index
        lda tmp_index
        cmp #$78            ; au-dela de H8 il n'y a plus de case utile
        bne de_boucle
        ; fallthrough

; ---------------------------------------------------------------------
;  dessiner_coordonnees : chiffres 8..1 a gauche, lettres A..H en bas
; ---------------------------------------------------------------------
dessiner_coordonnees
        lda #0
        sta tmp_rangee      ; rangee d'ecran r = 0..7
dco_boucle
        ; chiffre de la rangee : 8 - r, en colonne 0, ligne 3r + 1
        lda tmp_rangee
        asl a
        clc
        adc tmp_rangee      ; 3r
        clc
        adc #1
        ldx #COL_COORD
        jsr pos_ecran
        lda #8
        sec
        sbc tmp_rangee
        ora #CAR_ZERO
        ldy #0
        sta (ptr_ecran),y
        ; lettre de la colonne : A + r, en ligne 24, colonne x0 + 3
        lda tmp_rangee
        asl a
        clc
        adc tmp_rangee
        asl a               ; 6r
        clc
        adc #COL_ECH+DEC_LETTRE
        tax
        lda #LIG_LETTRES
        jsr pos_ecran
        lda tmp_rangee
        clc
        adc #CAR_A
        ldy #0
        sta (ptr_ecran),y
        inc tmp_rangee
        lda tmp_rangee
        cmp #8
        bne dco_boucle
        rts

; ---------------------------------------------------------------------
;  afficher_fixes : bandeaux en video inverse puis textes immuables
; ---------------------------------------------------------------------
afficher_fixes
        lda #LIG_TITRE
        jsr bandeau
        lda #LIG_H_PARTIE
        jsr bandeau
        lda #LIG_H_PRISES
        jsr bandeau
        lda #LIG_H_LEGENDE
        jsr bandeau
        lda #<textes_fixes
        sta ptr_aux
        lda #>textes_fixes
        sta ptr_aux+1
        jmp afficher_table

; bandeau : remplit la ligne A du panneau de blocs pleins
bandeau
        ldx #PAN_X
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #PAN_L
        jmp remplir

; ---------------------------------------------------------------------
;  decimal : decompose A (0..99) en v_dizaine et v_unite
; ---------------------------------------------------------------------
decimal
        ldx #$FF
        sec
-       inx
        sbc #10
        bcs -
        adc #10
        sta v_unite
        stx v_dizaine
        rts

; ---------------------------------------------------------------------
;  afficher_nb2 : ecrit A (0..99) sur 2 caracteres en (tmp_ligne, X)
;  Le zero de tete devient un espace : "1" et non "01".
; ---------------------------------------------------------------------
afficher_nb2
        sta pz_tmp
        lda tmp_ligne
        jsr pos_ecran
        lda pz_tmp
        jsr decimal
        lda v_dizaine
        bne an2_dizaine
        lda #CAR_ESPACE
        bne an2_pose        ; CAR_ESPACE n'est jamais nul
an2_dizaine
        ora #CAR_ZERO
an2_pose
        ora attr_texte
        ldy #0
        sta (ptr_ecran),y
        lda v_unite
        ora #CAR_ZERO
        ora attr_texte
        iny
        sta (ptr_ecran),y
        rts

; ---------------------------------------------------------------------
;  afficher_nb2z : comme afficher_nb2, mais avec le zero de tete
;  (les secondes de la pendule : "1:05" et non "1: 5")
; ---------------------------------------------------------------------
afficher_nb2z
        sta pz_tmp
        lda tmp_ligne
        jsr pos_ecran
        lda pz_tmp
        jsr decimal
        lda v_dizaine
        ora #CAR_ZERO
        ora attr_texte
        ldy #0
        sta (ptr_ecran),y
        lda v_unite
        ora #CAR_ZERO
        ora attr_texte
        iny
        sta (ptr_ecran),y
        rts

; ---------------------------------------------------------------------
;  nom_case : ecrit le nom d'une case (lettre + chiffre) en ptr_ecran
;  Entree  A = index 0x88, Y = decalage dans ptr_ecran
;  Sortie  Y avance de 2
; ---------------------------------------------------------------------
nom_case
        sta pz_tmp
        and #7
        clc
        adc #CAR_A
        ora attr_texte
        sta (ptr_ecran),y
        iny
        lda pz_tmp
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #CAR_ZERO+1
        ora attr_texte
        sta (ptr_ecran),y
        iny
        rts

; ---------------------------------------------------------------------
;  maj_panneau : TRAIT, ORDI, NIVEAU
; ---------------------------------------------------------------------
maj_panneau
        lda #0
        sta attr_texte
        ; --- TRAIT : camp au trait ---
        lda #LIG_TRAIT
        ldx #COL_VALEUR
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #PAN_T+PAN_LT-COL_VALEUR
        jsr remplir
        lda trait
        jsr nom_camp
        lda #LIG_TRAIT
        sta tmp_ligne
        lda #COL_VALEUR
        sta tmp_colonne
        lda ptr_aux
        ldx ptr_aux+1
        jsr afficher_en
        ; --- ORDI : camp tenu par la machine ---
        lda #LIG_ORDI
        ldx #COL_VALEUR
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #PAN_T+PAN_LT-COL_VALEUR
        jsr remplir
        lda camp_ordi
        cmp #ORDI_AUCUN
        bne mp_ordi_camp
        lda #<t_aucun
        ldx #>t_aucun
        jmp mp_ordi_poser
mp_ordi_camp
        jsr nom_camp
        lda ptr_aux
        ldx ptr_aux+1
mp_ordi_poser
        sta pz_tmp
        stx pz_tmp2
        lda #LIG_ORDI
        sta tmp_ligne
        lda #COL_VALEUR
        sta tmp_colonne
        lda pz_tmp
        ldx pz_tmp2
        jsr afficher_en
        ; profondeur atteinte par la derniere reflexion : "P4"
        lda camp_ordi
        cmp #ORDI_AUCUN
        beq mp_sans_prof
        lda rc_prof_faite
        beq mp_sans_prof
        lda #LIG_ORDI
        ldx #COL_VALEUR+8
        jsr pos_ecran
        ldy #0
        lda #CAR_P
        sta (ptr_ecran),y
        iny
        lda rc_prof_faite
        jsr decimal
        lda v_dizaine
        beq +
        ora #CAR_ZERO
        sta (ptr_ecran),y
        iny
+       lda v_unite
        ora #CAR_ZERO
        sta (ptr_ecran),y
mp_sans_prof
        ; --- NIVEAU : numero et nom ---
        lda #LIG_NIVEAU
        ldx #COL_VALEUR
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #PAN_T+PAN_LT-COL_VALEUR
        jsr remplir
        lda #LIG_NIVEAU
        sta tmp_ligne
        lda niveau
        ora #CAR_ZERO
        ldy #0
        sta (ptr_ecran),y
        ldx niveau
        dex
        lda niveau_nom_lo,x
        sta pz_tmp
        lda niveau_nom_hi,x
        sta pz_tmp2
        lda #COL_VALEUR+2
        sta tmp_colonne
        lda pz_tmp
        ldx pz_tmp2
        jmp afficher_en

; nom_camp : ptr_aux pointe "BLANCS" ou "NOIRS" selon A (BLANC / NOIR)
nom_camp
        beq +
        lda #<t_noirs
        ldx #>t_noirs
        jmp ++
+       lda #<t_blancs
        ldx #>t_blancs
+       sta ptr_aux
        stx ptr_aux+1
        rts

; ---------------------------------------------------------------------
;  afficher_reflexion : "REFLEXION... 4" pendant que l'ordinateur cherche
;  Le chiffre est la profondeur en cours d'exploration ; le joueur voit
;  ainsi que la machine travaille, et jusqu'ou elle est allee.
; ---------------------------------------------------------------------
afficher_reflexion
        lda #LIG_MSG
        jsr effacer_panneau_ligne
        lda #0
        sta attr_texte
        lda #LIG_MSG
        ldx #PAN_T
        jsr pos_ecran
        lda #<t_m_reflexion
        sta ptr_texte
        lda #>t_m_reflexion
        sta ptr_texte+1
        jsr afficher_texte
        jsr avancer_ecran
        lda rc_prof_iter
        jsr decimal
        lda v_dizaine
        beq +
        ora #CAR_ZERO
        sta (ptr_ecran),y
        iny
+       lda v_unite
        ora #CAR_ZERO
        sta (ptr_ecran),y
        lda #<t_m_stop
        ldx #>t_m_stop
        jmp message2

; ---------------------------------------------------------------------
;  maj_pendule : "MM:SS" depuis le debut de la partie
;
;  On accumule les jiffies ecoules depuis le dernier passage plutot que de
;  diviser l'horloge : l'accumulateur reste petit et quelques soustractions
;  suffisent. Les deux octets de poids faible de TI bouclent en 21 minutes,
;  donc tant que la pendule est consultee plus souvent que cela, le compte
;  est juste.
; ---------------------------------------------------------------------
maj_pendule
        ; delta = TI16 - pend_prec
        lda TI_BAS
        sec
        sbc pend_prec
        sta pz_tmp
        lda TI_MOYEN
        sbc pend_prec+1
        sta pz_tmp2
        lda TI_BAS
        sta pend_prec
        lda TI_MOYEN
        sta pend_prec+1
        ; accumulateur += delta
        lda pend_acc
        clc
        adc pz_tmp
        sta pend_acc
        lda pend_acc+1
        adc pz_tmp2
        sta pend_acc+1
mpe_secondes
        ; tant que l'accumulateur vaut au moins 50 images, une seconde passe
        lda pend_acc+1
        bne +
        lda pend_acc
        cmp #50
        bcc mpe_afficher
+       lda pend_acc
        sec
        sbc #50
        sta pend_acc
        lda pend_acc+1
        sbc #0
        sta pend_acc+1
        inc pend_sec
        lda pend_sec
        cmp #60
        bne mpe_secondes
        lda #0
        sta pend_sec
        inc pend_min
        lda pend_min
        cmp #100
        bne mpe_secondes
        lda #0
        sta pend_min
        jmp mpe_secondes
mpe_afficher
        lda #0
        sta attr_texte
        lda #LIG_PENDULE
        sta tmp_ligne
        lda pend_min
        ldx #COL_VALEUR
        jsr afficher_nb2
        lda #CAR_DEUXPTS
        ldy #2
        sta (ptr_ecran),y
        lda #LIG_PENDULE
        sta tmp_ligne
        lda pend_sec
        ldx #COL_VALEUR+3
        jmp afficher_nb2z

; ---------------------------------------------------------------------
;  message : affiche le texte (A = faible, X = fort) sur les deux lignes
;  de message du panneau. Le texte est coupe a PAN_LT caracteres ; un
;  second texte peut suivre sur la ligne du dessous (message2).
; ---------------------------------------------------------------------
message
        sta ptr_texte
        stx ptr_texte+1
        lda #LIG_MSG
        jsr effacer_panneau_ligne
        lda #LIG_MSG+1
        jsr effacer_panneau_ligne
        lda #0
        sta attr_texte
        lda #LIG_MSG
        ldx #PAN_T
        jsr pos_ecran
        jmp afficher_texte

; message2 : seconde ligne de message, sans effacer la premiere
message2
        sta ptr_texte
        stx ptr_texte+1
        lda #LIG_MSG+1
        jsr effacer_panneau_ligne
        lda #0
        sta attr_texte
        lda #LIG_MSG+1
        ldx #PAN_T
        jsr pos_ecran
        jmp afficher_texte
