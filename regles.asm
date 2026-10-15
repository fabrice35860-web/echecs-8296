; =====================================================================
;  regles.asm - la partie vue du joueur : position de depart, coup joue,
;  retour en arriere, fin de partie
;
;  Les regles elles-memes sont dans coups.asm, qui ne connait pas
;  l'ecran. Ce fichier-ci fait le lien : il tient a jour la liste des
;  coups legaux de la position affichee, joue le coup choisi, redessine
;  ce qui a bouge et annonce mat, pat ou nulle.
; =====================================================================

; ---------------------------------------------------------------------
;  nouvelle_partie : remet la position de depart et redessine tout
; ---------------------------------------------------------------------
nouvelle_partie
        ; plateau vide, y compris les cases hors echiquier
        lda #VIDE
        ldx #0
np_vider
        sta plateau,x
        inx
        bpl np_vider        ; 0..127, le bit 7 arrete la boucle
        ; les deux rangees de chaque camp
        ldx #0
np_rangee
        lda rangee_depart,x
        sta plateau,x               ; rangee 1 : index $00 + colonne
        ora #NOIR
        sta plateau+$70,x           ; rangee 8 : index $70 + colonne
        lda #PION_B
        sta plateau+$10,x           ; rangee 2
        lda #PION_N
        sta plateau+$60,x           ; rangee 7
        inx
        cpx #8
        bne np_rangee
        ; etat de la partie
        lda #BLANC
        sta trait
        lda #ROQUE_TOUS
        sta droits_roque
        lda #AUCUNE_CASE
        sta case_ep
        lda #0
        sta demi_50
        lda #CASE_E1
        sta pos_roi
        lda #CASE_E1+RANGEE_8
        sta pos_roi+1
        lda #CASE_DEPART
        sta curseur
        lda #$FF
        sta selection
        lda #0
        sta partie_finie
        sta nb_demi_coups
        sta nb_demi_hi
        sta nb_prises
        sta nb_notes
        sta mode_saisie
        sta nb_saisie
        sta attente_conf
        sta attente_promo
        ; notation et pieces prises : tout en blanc
        lda #CAR_ESPACE
        ldx #NOTE_LG*NOTE_NB-1
-       sta notation,x
        dex
        bpl -
        lda #0
        ldx #PRISES_MAX-1
-       sta prises,x
        dex
        bpl -
        ; pendule a zero
        sta pend_sec
        sta pend_min
        sta pend_acc
        sta pend_acc+1
        lda TI_BAS
        sta pend_prec
        lda TI_MOYEN
        sta pend_prec+1
        ; les coups legaux de la position de depart
        jsr calculer_coups
        ; affichage
        jsr dessiner_echiquier
        jsr maj_panneau
        jsr maj_pendule
        jsr afficher_notation
        jsr afficher_prises
        jsr maj_saisie
        lda #<t_m_nouvelle
        ldx #>t_m_nouvelle
        jsr message
        jmp message_trait

; ---------------------------------------------------------------------
;  message_trait : rappelle le camp au trait sur la seconde ligne
; ---------------------------------------------------------------------
message_trait
        lda trait
        bne mt_noirs
        lda #<t_m_a_blancs
        ldx #>t_m_a_blancs
        jmp message2
mt_noirs
        lda #<t_m_a_noirs
        ldx #>t_m_a_noirs
        jmp message2

; ---------------------------------------------------------------------
;  piece_au_trait : la piece de la case A est-elle du camp au trait ?
;  Sortie  Z = 1 si oui ; une case vide repond non
; ---------------------------------------------------------------------
piece_au_trait
        tax
        lda plateau,x
        beq pat_non
        and #MASQUE_COUL
        cmp trait
        rts
pat_non
        lda #$FF            ; une valeur non nulle : ce n'est pas au trait
        rts

; ---------------------------------------------------------------------
;  calculer_coups : refait la liste des coups legaux du camp au trait
;  Elle sert a trois choses : accepter ou refuser le coup demande,
;  marquer les destinations a l'ecran, et reconnaitre le mat du pat.
; ---------------------------------------------------------------------
calculer_coups
        lda #<LISTE_PARTIE
        sta coups_fin
        lda #>LISTE_PARTIE
        sta coups_fin+1
        jsr generer_legaux
        lda gc_nb
        sta nb_coups_partie
        rts

; ---------------------------------------------------------------------
;  coup_possible : le coup cp_depart -> cp_arrivee est-il legal ?
;  Cherche dans la liste des coups legaux. Une promotion y figure quatre
;  fois, une par piece possible : nb_variantes les compte, et cp_drapeau
;  retient la premiere, c'est-a-dire la dame.
;  Sortie  Z = 1 si le coup est accepte
; ---------------------------------------------------------------------
coup_possible
        lda #0
        sta nb_variantes
        lda #<LISTE_PARTIE
        sta ptr_coup
        lda #>LISTE_PARTIE
        sta ptr_coup+1
        ldx nb_coups_partie
        beq cps_non
cps_boucle
        ldy #0
        lda (ptr_coup),y
        cmp cp_depart
        bne cps_suivant
        iny
        lda (ptr_coup),y
        cmp cp_arrivee
        bne cps_suivant
        iny
        lda (ptr_coup),y
        ldy nb_variantes
        bne cps_deja
        sta cp_drapeau
cps_deja
        inc nb_variantes
cps_suivant
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc +
        inc ptr_coup+1
+       dex
        bne cps_boucle
        lda nb_variantes
        beq cps_non
        lda #0
        rts
cps_non
        lda #$FF
        rts

; ---------------------------------------------------------------------
;  est_destination : la case A est-elle une arrivee legale de la piece
;  choisie ? Sortie C = 1 si oui.
; ---------------------------------------------------------------------
est_destination
        sta ed_case
        ldy selection
        bmi ed_non
        lda #<LISTE_PARTIE
        sta ptr_aux
        lda #>LISTE_PARTIE
        sta ptr_aux+1
        ldx nb_coups_partie
        beq ed_non
ed_boucle
        ldy #0
        lda (ptr_aux),y
        cmp selection
        bne ed_suivant
        iny
        lda (ptr_aux),y
        cmp ed_case
        beq ed_oui
ed_suivant
        lda ptr_aux
        clc
        adc #COUP_OCTETS
        sta ptr_aux
        bcc +
        inc ptr_aux+1
+       dex
        bne ed_boucle
ed_non
        clc
        rts
ed_oui
        sec
        rts

; ---------------------------------------------------------------------
;  piece_jouable : la piece de la case A a-t-elle au moins un coup ?
;  Sortie  C = 1 si oui
; ---------------------------------------------------------------------
piece_jouable
        sta ed_case
        lda #<LISTE_PARTIE
        sta ptr_aux
        lda #>LISTE_PARTIE
        sta ptr_aux+1
        ldx nb_coups_partie
        beq pj_non
pj_boucle
        ldy #0
        lda (ptr_aux),y
        cmp ed_case
        beq ed_oui
        lda ptr_aux
        clc
        adc #COUP_OCTETS
        sta ptr_aux
        bcc +
        inc ptr_aux+1
+       dex
        bne pj_boucle
pj_non
        clc
        rts

; ---------------------------------------------------------------------
;  jouer_coup : joue le coup trouve par coup_possible
;  Quand plusieurs pieces de promotion sont possibles, le coup attend le
;  choix du joueur au lieu d'etre joue tout de suite.
; ---------------------------------------------------------------------
jouer_coup
        lda nb_variantes
        cmp #2
        bcc jouer_coup_effectif
        lda #1
        sta attente_promo
        jsr effacer_destinations
        lda #<t_m_promotion
        ldx #>t_m_promotion
        jsr message
        lda #<t_m_promo2
        ldx #>t_m_promo2
        jmp message2

; jouer_promo : la touche A designe la piece de promotion (0 = la dame
; par defaut). Le drapeau garde le type demande.
jouer_promo
        ldx #3
jp_chercher
        cmp promo_lettres,x
        beq jp_trouve
        dex
        bpl jp_chercher
        rts                 ; une autre touche : on attend toujours
jp_trouve
        lda promo_types,x
        ora #CP_PROMO
        sta cp_drapeau
        ; fall through

jouer_coup_effectif
        lda #0
        sta attente_promo
        jsr effacer_destinations
        jsr glisser_hist
        jsr jouer_interne   ; remplit cp_piece et cp_prise
        ; trace du coup dans le panneau
        lda cp_prise
        beq +
        jsr ajouter_prise
+       jsr ajouter_notation
        jsr redessiner_coup
        ; le curseur suit la piece jouee, et plus rien n'est choisi
        lda curseur
        sta pz_tmp3
        lda cp_arrivee
        sta curseur
        lda #$FF
        sta selection
        lda pz_tmp3
        jsr dessiner_case
        lda curseur
        jsr dessiner_case
        ; au camp suivant de jouer
        jsr calculer_coups
        jsr tester_fin
        jsr maj_panneau
        jsr afficher_notation
        jsr afficher_prises
        jsr maj_saisie
        jmp message_etat

; ---------------------------------------------------------------------
;  redessiner_coup : les cases que le coup a changees. Un roque en
;  deplace deux de plus, une prise en passant vide une case voisine.
; ---------------------------------------------------------------------
redessiner_coup
        lda cp_depart
        jsr dessiner_case
        lda cp_arrivee
        jsr dessiner_case
        lda cp_drapeau
        cmp #CP_EP
        beq rc_ep
        cmp #CP_PETIT
        beq rc_petit
        cmp #CP_GRAND
        beq rc_grand
        rts
rc_ep
        jsr ji_case_pion_ep
        txa
        jmp dessiner_case
rc_petit
        lda cp_arrivee
        clc
        adc #1
        jsr dessiner_case
        lda cp_arrivee
        sec
        sbc #1
        jmp dessiner_case
rc_grand
        lda cp_arrivee
        sec
        sbc #2
        jsr dessiner_case
        lda cp_arrivee
        clc
        adc #1
        jmp dessiner_case

; ---------------------------------------------------------------------
;  glisser_hist : quand la pile des coups approche de sa fin, le plus
;  ancien demi-coup est oublie pour faire de la place. La partie devrait
;  etre nulle bien avant d'en arriver la ; c'est une securite, et elle
;  n'intervient jamais pendant une recherche, qui empile par-dessus.
; ---------------------------------------------------------------------
glisser_hist
        lda nb_demi_hi
        cmp #>HIST_MAX
        bcc gh_fin
        bne gh_glisser
        lda nb_demi_coups
        cmp #<HIST_MAX
        bcc gh_fin
gh_glisser
        ; tout remonte d'une entree vers le bas de la zone
        lda #<hist_zone
        sta ptr_hist
        lda #>hist_zone
        sta ptr_hist+1
        lda #<(hist_zone+HIST_OCTETS)
        sta ptr_aux
        lda #>(hist_zone+HIST_OCTETS)
        sta ptr_aux+1
        ldx #HIST_PAGES
gh_page
        ldy #0
gh_octet
        lda (ptr_aux),y
        sta (ptr_hist),y
        iny
        bne gh_octet
        inc ptr_hist+1
        inc ptr_aux+1
        dex
        bne gh_page
        lda nb_demi_coups
        sec
        sbc #1
        sta nb_demi_coups
        bcs gh_fin
        dec nb_demi_hi
gh_fin
        rts

; ---------------------------------------------------------------------
;  tester_fin : mat, pat, nulles. partie_finie garde la cause.
; ---------------------------------------------------------------------
tester_fin
        lda #0
        sta partie_finie
        lda nb_coups_partie
        bne tf_nulles
        lda trait
        jsr roi_en_echec
        lda #FIN_PAT
        bcc tf_poser
        lda #FIN_MAT
tf_poser
        sta partie_finie
        rts
tf_nulles
        lda demi_50
        cmp #100            ; 50 coups = 100 demi-coups
        bcc tf_materiel
        lda #FIN_50
        sta partie_finie
        rts
tf_materiel
        jsr materiel_insuffisant
        bcc tf_repetition
        lda #FIN_MATERIEL
        sta partie_finie
        rts
tf_repetition
        jsr tester_repetition
        bcc tf_fin
        lda #FIN_REPETITION
        sta partie_finie
tf_fin
        rts

; ---------------------------------------------------------------------
;  materiel_insuffisant : aucun des deux camps ne peut mater ?
;  Sortie  C = 1 si la partie est nulle de ce fait.
;
;  Un pion, une tour ou une dame suffisent toujours a mater. Restent les
;  pieces mineures : roi seul contre roi seul, roi et une mineure contre
;  roi seul, et les deux fous de meme couleur de case.
; ---------------------------------------------------------------------
materiel_insuffisant
        lda #0
        sta mi_compte
        sta mi_compte+1
        sta mi_fous_b
        sta mi_fous_n
        ldx #0
mi_boucle
        txa
        and #HORS_ECH
        bne mi_suivant
        lda plateau,x
        beq mi_suivant
        pha
        and #MASQUE_TYPE
        cmp #ROI
        beq mi_pop
        cmp #CAVALIER
        beq mi_mineure
        cmp #FOU
        beq mi_fou
        pla
        clc                 ; pion, tour ou dame : on peut encore mater
        rts
mi_fou
        ; couleur de la case : (rangee + colonne) impair = case foncee
        txa
        lsr a
        lsr a
        lsr a
        lsr a
        sta mi_tmp
        txa
        and #7
        clc
        adc mi_tmp
        and #1
        sta mi_tmp          ; 0 = case claire, 1 = case foncee
        pla
        pha
        and #MASQUE_COUL
        beq mi_fou_blanc
        lda mi_fous_n
        ora #2
        sta mi_fous_n
        lda mi_tmp
        beq mi_fou_n_clair
        lda mi_fous_n
        ora #1
        sta mi_fous_n
mi_fou_n_clair
        jmp mi_mineure
mi_fou_blanc
        lda mi_fous_b
        ora #2
        sta mi_fous_b
        lda mi_tmp
        beq mi_mineure
        lda mi_fous_b
        ora #1
        sta mi_fous_b
mi_mineure
        pla
        pha
        and #MASQUE_COUL
        bne mi_mineure_n
        inc mi_compte
        jmp mi_pop
mi_mineure_n
        inc mi_compte+1
mi_pop
        pla
mi_suivant
        inx
        bpl mi_boucle
        ; au plus une mineure en tout : rien ne mate
        lda mi_compte
        clc
        adc mi_compte+1
        cmp #2
        bcc mi_nulle
        ; deux mineures : nulle seulement si c'est un fou de chaque camp,
        ; et sur des cases de meme couleur
        cmp #2
        bne mi_pas_nulle
        lda mi_compte
        cmp #1
        bne mi_pas_nulle
        lda mi_compte+1
        cmp #1
        bne mi_pas_nulle
        lda mi_fous_b
        and #2
        beq mi_pas_nulle    ; ce n'est pas un fou
        lda mi_fous_n
        and #2
        beq mi_pas_nulle
        lda mi_fous_b
        eor mi_fous_n
        and #1
        bne mi_pas_nulle    ; cases de couleurs differentes : on peut mater
mi_nulle
        sec
        rts
mi_pas_nulle
        clc
        rts

; ---------------------------------------------------------------------
;  tester_repetition : la position courante s'est-elle deja presentee
;  deux fois ? Sortie C = 1 si oui (troisieme occurrence).
;
;  Plutot qu'un hachage, on remonte le fil de la partie en defaisant les
;  coups jusqu'a la derniere prise ou le dernier coup de pion, au-dela
;  desquels aucune position ne peut se repeter, puis on rejoue tout. La
;  position de depart etant gardee a part, la comparaison porte sur le
;  plateau, les droits de roque et la case de prise en passant.
; ---------------------------------------------------------------------
tester_repetition
        lda demi_50
        cmp #4              ; il faut au moins quatre demi-coups
        bcs tr_depart
        clc
        rts
tr_depart
        ; demi_50 est restaure par chaque annulation : on fige la borne
        ; avant de remonter le fil de la partie
        sta tr_max
        ldx #127
-       lda plateau,x
        sta plateau_ref,x
        dex
        bpl -
        lda droits_roque
        sta roque_ref
        lda case_ep
        sta ep_ref
        lda #0
        sta tr_vues
        sta tr_recul
tr_reculer
        lda tr_recul
        cmp tr_max
        bcs tr_rejouer
        jsr annuler_interne
        inc tr_recul
        ; seules les positions du meme camp au trait comptent
        lda tr_recul
        and #1
        bne tr_reculer
        jsr comparer_position
        bcc tr_reculer
        inc tr_vues
        jmp tr_reculer
tr_rejouer
        lda tr_recul
        beq tr_verdict
        jsr rejouer_dernier
        dec tr_recul
        jmp tr_rejouer
tr_verdict
        lda tr_vues
        cmp #2              ; deux fois avant, plus celle-ci : trois
        bcc tr_non
        sec
        rts
tr_non
        clc
        rts

; comparer_position : la position courante est-elle celle gardee ?
comparer_position
        lda droits_roque
        cmp roque_ref
        bne cmp_non
        lda case_ep
        cmp ep_ref
        bne cmp_non
        ldx #127
-       lda plateau,x
        cmp plateau_ref,x
        bne cmp_non
        dex
        bpl -
        sec
        rts
cmp_non
        clc
        rts

; rejouer_dernier : rejoue le coup qui vient d'etre defait. Son entree
; est encore en place dans la pile, a l'index nb_demi_coups.
rejouer_dernier
        jsr pos_hist
        ldy #0
        lda (ptr_hist),y
        sta cp_depart
        iny
        lda (ptr_hist),y
        sta cp_arrivee
        ldy #7
        lda (ptr_hist),y
        sta cp_drapeau
        jmp jouer_interne

; ---------------------------------------------------------------------
;  message_etat : ce que le panneau annonce apres un coup
; ---------------------------------------------------------------------
message_etat
        lda partie_finie
        beq me_en_cours
        cmp #FIN_MAT
        beq me_mat
        cmp #FIN_PAT
        beq me_pat
        cmp #FIN_50
        beq me_50
        cmp #FIN_MATERIEL
        beq me_materiel
        lda #<t_m_nulle_rep
        ldx #>t_m_nulle_rep
        jmp me_nulle
me_50
        lda #<t_m_nulle50
        ldx #>t_m_nulle50
        jmp me_nulle
me_materiel
        lda #<t_m_nulle_mat
        ldx #>t_m_nulle_mat
        jmp me_nulle
me_pat
        lda #<t_m_pat
        ldx #>t_m_pat
me_nulle
        jsr message
        lda #<t_m_finie
        ldx #>t_m_finie
        jmp message2
me_mat
        ; le camp au trait est mat : c'est l'autre qui gagne
        lda #<t_m_mat
        ldx #>t_m_mat
        jsr message
        lda trait
        eor #NOIR
        jsr nom_camp        ; ptr_aux = "BLANCS" ou "NOIRS"
        lda #LIG_MSG+1
        jsr effacer_panneau_ligne
        lda #0
        sta attr_texte
        lda #LIG_MSG+1
        ldx #PAN_T
        jsr pos_ecran
        lda ptr_aux
        sta ptr_texte
        lda ptr_aux+1
        sta ptr_texte+1
        jsr afficher_texte
        jsr avancer_ecran
        lda #<t_m_gagnent
        sta ptr_texte
        lda #>t_m_gagnent
        sta ptr_texte+1
        jmp afficher_texte
me_en_cours
        lda trait
        jsr roi_en_echec
        bcc me_simple
        lda #<t_m_echec
        ldx #>t_m_echec
        jsr message
        jmp message_trait
me_simple
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp message_trait

; ---------------------------------------------------------------------
;  annuler_coup : defait le dernier demi-coup joue
;  Sortie  Z = 1 si un coup a bien ete annule
; ---------------------------------------------------------------------
annuler_coup
        lda nb_demi_coups
        ora nb_demi_hi
        bne ac_depiler
        lda #$FF            ; rien a annuler
        rts
ac_depiler
        jsr effacer_destinations
        jsr annuler_interne ; remplit cp_depart, cp_arrivee, cp_drapeau
        ; defaire aussi la trace du coup
        lda cp_prise
        beq +
        jsr retirer_prise
+       jsr retirer_notation
        ; le curseur revient sur la piece revenue
        lda curseur
        sta pz_tmp3
        lda cp_depart
        sta curseur
        lda #$FF
        sta selection
        lda #0
        sta attente_promo
        jsr redessiner_coup
        lda pz_tmp3
        jsr dessiner_case
        lda curseur
        jsr dessiner_case
        jsr calculer_coups
        jsr tester_fin
        jsr maj_panneau
        jsr afficher_notation
        jsr afficher_prises
        jsr maj_saisie
        lda #0              ; Z = 1 : un coup a ete annule
        rts

; ---------------------------------------------------------------------
;  ajouter_prise / retirer_prise : la liste des pieces capturees
;  Une piece blanche prise s'ecrit en video inverse, comme elle apparait
;  sur l'echiquier (lumineux = blancs).
; ---------------------------------------------------------------------
ajouter_prise
        ldx nb_prises
        cpx #PRISES_MAX
        bcs ap_fin
        lda cp_prise
        and #MASQUE_TYPE
        tay
        lda lettres_pieces-1,y
        ldy cp_prise
        cpy #NOIR
        bcs +
        ora #INVERSE        ; piece blanche : lumineuse
+       sta prises,x
        inc nb_prises
ap_fin
        rts

retirer_prise
        lda nb_prises
        beq +
        dec nb_prises
        ldx nb_prises
        lda #0
        sta prises,x
+       rts

; ---------------------------------------------------------------------
;  afficher_prises : la ligne des pieces capturees
; ---------------------------------------------------------------------
afficher_prises
        lda #LIG_PRISES
        jsr effacer_panneau_ligne
        lda #LIG_PRISES
        ldx #PAN_T
        jsr pos_ecran
        ldy #0
ape_boucle
        cpy nb_prises
        bcs ape_fin
        lda prises,y
        sta (ptr_ecran),y
        iny
        bne ape_boucle
ape_fin
        rts

; ---------------------------------------------------------------------
;  ajouter_notation : ecrit le coup courant dans la liste des derniers
;  coups, au format lettre de piece + depart + separateur + arrivee
;  ("CG1-F3", "FF1XB5"). La liste defile quand elle est pleine.
; ---------------------------------------------------------------------
ajouter_notation
        lda nb_notes
        cmp #NOTE_NB
        bcc an_place
        ; liste pleine : tout decale d'une entree vers la gauche
        ldx #0
an_decaler
        lda notation+NOTE_LG,x
        sta notation,x
        inx
        cpx #NOTE_LG*(NOTE_NB-1)
        bne an_decaler
        dec nb_notes
an_place
        ; index de l'entree = nb_notes * NOTE_LG
        lda nb_notes
        asl a
        asl a
        clc
        adc nb_notes
        adc nb_notes        ; x6
        tax
        ; les roques ont leur ecriture a eux
        lda cp_drapeau
        cmp #CP_PETIT
        beq an_petit
        cmp #CP_GRAND
        beq an_grand
        ; lettre de la piece ; un pion n'en porte pas, sauf s'il promeut :
        ; la lettre est alors celle de la piece obtenue ("DE7-E8")
        lda cp_drapeau
        cmp #CP_PROMO
        bcs an_promue
        lda cp_piece
        and #MASQUE_TYPE
        cmp #PION
        beq an_pion
        tay
        lda lettres_pieces-1,y
        jmp an_poser_lettre
an_promue
        and #MASQUE_TYPE
        tay
        lda lettres_pieces-1,y
        jmp an_poser_lettre
an_pion
        lda #CAR_ESPACE
an_poser_lettre
        sta notation,x
        inx
        ; case de depart
        lda cp_depart
        jsr note_case
        ; separateur : X pour une prise, sinon un tiret
        lda cp_prise
        beq an_tiret
        lda #CAR_PRISE
        jmp an_poser_sep
an_tiret
        lda #CAR_TIRET
an_poser_sep
        sta notation,x
        inx
        ; case d'arrivee
        lda cp_arrivee
        jsr note_case
        inc nb_notes
        rts

; an_petit / an_grand : "O-O" et "O-O-O", completes par des espaces
an_petit
        lda #<t_note_petit
        ldy #>t_note_petit
        jmp an_copier
an_grand
        lda #<t_note_grand
        ldy #>t_note_grand
an_copier
        sta ptr_aux
        sty ptr_aux+1
        ldy #0
-       lda (ptr_aux),y
        sta notation,x
        inx
        iny
        cpy #NOTE_LG
        bne -
        inc nb_notes
        rts

; note_case : ecrit la lettre et le chiffre de la case A en notation,x
note_case
        sta pz_tmp
        and #7
        clc
        adc #CAR_A
        sta notation,x
        inx
        lda pz_tmp
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #CAR_ZERO+1
        sta notation,x
        inx
        rts

retirer_notation
        lda nb_notes
        beq rn_fin
        dec nb_notes
        ; l'entree liberee repasse en blanc
        lda nb_notes
        asl a
        asl a
        clc
        adc nb_notes
        adc nb_notes
        tax
        ldy #NOTE_LG
        lda #CAR_ESPACE
-       sta notation,x
        inx
        dey
        bne -
rn_fin
        rts

; ---------------------------------------------------------------------
;  afficher_notation : les derniers coups, quatre par ligne
; ---------------------------------------------------------------------
afficher_notation
        lda #LIG_COUPS
        jsr effacer_panneau_ligne
        lda #LIG_COUPS+1
        jsr effacer_panneau_ligne
        lda #0
        sta tmp_index       ; numero d'entree
anot_boucle
        lda tmp_index
        cmp #NOTE_NB
        bcs anot_fin
        ; ligne = LIG_COUPS + entree / 4, colonne = PAN_T + 7 * (entree mod 4)
        lda tmp_index
        lsr a
        lsr a
        clc
        adc #LIG_COUPS
        sta tmp_ligne
        lda tmp_index
        and #3
        sta pz_tmp
        asl a
        asl a
        asl a               ; x8
        sec
        sbc pz_tmp          ; x7
        clc
        adc #PAN_T
        tax
        lda tmp_ligne
        jsr pos_ecran
        ; index dans notation = entree * NOTE_LG
        lda tmp_index
        asl a
        asl a
        clc
        adc tmp_index
        adc tmp_index
        tax
        ldy #0
-       lda notation,x
        sta (ptr_ecran),y
        inx
        iny
        cpy #NOTE_LG
        bne -
        inc tmp_index
        jmp anot_boucle
anot_fin
        rts

; ---------------------------------------------------------------------
;  tour_ordinateur : si la machine tient le camp au trait, elle cherche
;  son coup et le joue. Appelee depuis la boucle principale, elle ne
;  fait rien dans une partie entre deux joueurs humains.
; ---------------------------------------------------------------------
tour_ordinateur
        lda partie_finie
        bne to_fin
        lda camp_ordi
        cmp #ORDI_AUCUN
        beq to_fin
        cmp trait
        bne to_fin
        jsr effacer_destinations
        jsr chercher_coup
        bcc to_fin          ; mat ou pat : tester_fin l'a deja dit
        lda #1
        sta nb_variantes    ; le drapeau du coup est deja celui qu'il faut
        jmp jouer_coup_effectif
to_fin
        rts

; ---------------------------------------------------------------------
;  changer_camp_ordi : fait tourner AUCUN -> NOIRS -> BLANCS -> AUCUN
;  Quand l'ordinateur prend le camp au trait, il joue aussitot.
; ---------------------------------------------------------------------
changer_camp_ordi
        lda camp_ordi
        cmp #ORDI_AUCUN
        beq cco_noirs
        cmp #NOIR
        beq cco_blancs
        lda #ORDI_AUCUN
        bne cco_poser
cco_noirs
        lda #NOIR
        bne cco_poser
cco_blancs
        lda #BLANC
cco_poser
        sta camp_ordi
        jsr deselectionner
        jsr maj_panneau
        rts
