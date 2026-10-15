; =====================================================================
;  recherche.asm - l'adversaire : alpha-beta, recherche de calme,
;  approfondissement iteratif
;
;  Negamax : a chaque demi-coup le score change de signe, si bien qu'une
;  seule routine sert aux deux camps. La fenetre alpha-beta coupe les
;  branches dont on sait deja qu'elles ne changeront rien au choix.
;
;  Les variables de la recursion sont des tableaux indexes par le niveau
;  (rc_niv) plutot que des sauvegardes sur la pile : la pile du 6502 ne
;  fait que 256 octets, et le debogage y serait penible.
;
;  Les scores sont en centipions, sur seize bits signes. Un mat vaut
;  MAT_SCORE moins le nombre de demi-coups qu'il faut pour l'atteindre,
;  de sorte qu'un mat rapide l'emporte sur un mat lointain.
; =====================================================================

; ---------------------------------------------------------------------
;  chercher_coup : trouve le coup que l'ordinateur veut jouer
;  Sortie  C = 1 et cp_depart / cp_arrivee / cp_drapeau remplis ;
;          C = 0 si la position n'offre aucun coup (mat ou pat)
;
;  Approfondissement iteratif : on cherche a un demi-coup, puis deux,
;  etc. La recherche precedente sert a montrer d'abord son meilleur coup,
;  ce qui fait couper bien plus tot. On s'arrete quand le temps imparti
;  au niveau est ecoule, ou sur STOP.
; ---------------------------------------------------------------------
chercher_coup
        lda #0
        sta rc_arret
        sta rc_trouve
        sta rc_niv
        sta rc_prof_faite
        ; depart du chronometre
        lda TI_BAS
        sta rc_depart
        lda TI_MOYEN
        sta rc_depart+1
        ; profondeur et temps que le niveau accorde
        ldx niveau
        lda prof_niveau-1,x
        sta rc_prof_max
        lda temps_niveau_lo-1,x
        sta rc_limite
        lda temps_niveau_hi-1,x
        sta rc_limite+1
        lda #1
        sta rc_prof_iter
cc_iteration
        lda #<RECHERCHE_ZONE
        sta coups_fin
        lda #>RECHERCHE_ZONE
        sta coups_fin+1
        lda rc_prof_iter
        sta rc_prof
        jsr afficher_reflexion
        jsr racine
        lda rc_arret
        bne cc_fini        ; le temps a manque : on garde l'iteration d'avant
        ; cette profondeur est allee au bout : son coup fait foi
        lda rc_prof_iter
        sta rc_prof_faite
        ldx #COUP_OCTETS-1
-       lda rc_coup_iter,x
        sta rc_coup,x
        dex
        bpl -
        lda #1
        sta rc_trouve
        ; un mat trouve ne demande pas d'aller plus loin
        jsr rc_est_mat
        bcs cc_fini
        inc rc_prof_iter
        lda rc_prof_iter
        cmp rc_prof_max
        beq +
        bcs cc_fini
+       jsr temps_ecoule
        bcc cc_iteration
cc_fini
        lda rc_trouve
        bne cc_jouer
        ; le temps a manque avant la fin de la premiere iteration : on
        ; prend le meilleur coup qu'elle avait deja trouve
        lda rc_a_un_coup
        beq cc_aucun
        ldx #COUP_OCTETS-1
-       lda rc_coup_iter,x
        sta rc_coup,x
        dex
        bpl -
cc_jouer
        lda rc_coup
        sta cp_depart
        lda rc_coup+1
        sta cp_arrivee
        lda rc_coup+2
        sta cp_drapeau
        sec
        rts
cc_aucun
        clc
        rts

; rc_est_mat_score : rc_score annonce-t-il un mat ? C = 1 si oui.
rc_est_mat_score
        lda rc_score+1
        bpl +
        sec
        lda #0
        sbc rc_score
        lda #0
        sbc rc_score+1
+       cmp #>MAT_SEUIL
        bcc +
        sec
        rts
+       clc
        rts

; rc_est_mat : le score retenu annonce-t-il un mat ? C = 1 si oui.
rc_est_mat
        lda rc_score_iter+1
        bpl +
        ; score negatif : on regarde sa valeur absolue
        sec
        lda #0
        sbc rc_score_iter
        lda #0
        sbc rc_score_iter+1
+       cmp #>MAT_SEUIL
        bcc rem_non
        sec
        rts
rem_non
        clc
        rts

; ---------------------------------------------------------------------
;  racine : la recherche au premier demi-coup
;  Elle se distingue du reste en ceci qu'elle retient le coup, pas
;  seulement le score, et qu'elle met a jour l'affichage.
; ---------------------------------------------------------------------
racine
        lda #<(-MAT_SCORE)
        sta rc_alpha
        lda #>(-MAT_SCORE)
        sta rc_alpha+1
        lda #0
        sta rc_a_un_coup
        ; les coups de la position. On en garde les bornes a part :
        ; ptr_liste sert a chaque niveau et les enfants l'ecrasent.
        lda coups_fin
        sta ptr_liste
        sta rc_deb_rac
        lda coups_fin+1
        sta ptr_liste+1
        sta rc_deb_rac+1
        jsr generer_coups
        jsr noter_coups
        lda coups_fin
        sta rc_fin_rac
        lda coups_fin+1
        sta rc_fin_rac+1
        ; le meilleur coup de l'iteration precedente passe en tete
        lda rc_trouve
        beq ra_boucle
        jsr pousser_coup_connu
ra_boucle
        jsr choisir_meilleur
        bcs ra_essayer
        jmp ra_fin
ra_essayer
        jsr charger_coup
        jsr jouer_interne
        jsr echec_apres_coup
        bcc ra_legal
        jmp ra_annuler
ra_legal
        lda #1
        sta rc_a_un_coup
        ; Fenetre du fils : [-infini, -alpha]. Aux deux premiers niveaux
        ; on la laisse entiere, pour que chaque coup recoive un score
        ; exact : le grain de hasard ajoute plus bas departagerait sinon
        ; des scores tronques par la fenetre, et le dernier coup essaye
        ; l'emporterait toujours.
        lda niveau
        cmp #3
        bcc ra_fenetre_large
        lda rc_alpha
        sta rc_beta_fils
        lda rc_alpha+1
        sta rc_beta_fils+1
        jsr rc_nier_beta_fils
        jmp ra_fenetre_fin
ra_fenetre_large
        lda #<MAT_SCORE
        sta rc_beta_fils
        lda #>MAT_SCORE
        sta rc_beta_fils+1
ra_fenetre_fin
        lda #<(-MAT_SCORE)
        sta rc_alpha_fils
        lda #>(-MAT_SCORE)
        sta rc_alpha_fils+1
        ldx #0
        stx rc_niv
        lda rc_prof
        sec
        sbc #1
        sta rc_prof_fils
        jsr negamax                 ; rend rc_score
        jsr rc_nier_score
        jsr annuler_interne
        ; Aux deux premiers niveaux, un grain de hasard departage les
        ; coups de valeur voisine : l'ordinateur ne rejoue pas toujours
        ; la meme partie contre un debutant.
        lda niveau
        cmp #3
        bcs ra_juger
        jsr rc_est_mat_score
        bcs ra_juger        ; un mat ne se tire pas au sort
        jsr alea
        and #$0F
        clc
        adc rc_score
        sta rc_score
        bcc ra_juger
        inc rc_score+1
ra_juger
        ; mieux que ce qu'on avait ?
        jsr rc_score_sup_alpha
        bcc ra_suivant
        lda rc_score
        sta rc_alpha
        sta rc_score_iter
        lda rc_score+1
        sta rc_alpha+1
        sta rc_score_iter+1
        lda cp_depart
        sta rc_coup_iter
        lda cp_arrivee
        sta rc_coup_iter+1
        lda cp_drapeau
        sta rc_coup_iter+2
        jmp ra_suivant
ra_annuler
        jsr annuler_interne
ra_suivant
        lda rc_arret
        bne ra_fin
        jsr temps_ecoule
        bcs ra_stop
        jmp ra_boucle
ra_stop
        lda #1
        sta rc_arret
ra_fin
        lda rc_a_un_coup
        bne +
        lda #0
        sta rc_trouve               ; aucun coup legal : mat ou pat
+       rts

; ---------------------------------------------------------------------
;  negamax : la recherche proprement dite
;  Entree  rc_prof_fils, rc_alpha_fils, rc_beta_fils, rc_niv
;  Sortie  rc_score
; ---------------------------------------------------------------------
negamax
        ; pf_nb compte les positions examinees. Le jeu ne s'en sert pas,
        ; mais test_ia.prg l'affiche : savoir combien de noeuds a coute un
        ; coup est ce qui dit si une optimisation a servi a quelque chose.
        inc pf_nb
        bne +
        inc pf_nb+1
        bne +
        inc pf_nb+2
        bne +
        inc pf_nb+3
+       ldx rc_niv
        lda rc_prof_fils
        sta rc_t_prof,x
        lda rc_alpha_fils
        sta rc_t_alpha_lo,x
        lda rc_alpha_fils+1
        sta rc_t_alpha_hi,x
        lda rc_beta_fils
        sta rc_t_beta_lo,x
        lda rc_beta_fils+1
        sta rc_t_beta_hi,x
        lda rc_prof_fils
        bne nm_descendre
        jmp quiescence
nm_descendre
        ; la liste de coups de ce niveau commence ou s'arrete la place
        ldx rc_niv
        lda coups_fin
        sta rc_t_deb_lo,x
        sta ptr_liste       ; noter_coups note cette tranche-la, pas tout
        lda coups_fin+1
        sta rc_t_deb_hi,x
        sta ptr_liste+1
        jsr generer_coups
        jsr noter_coups
        ldx rc_niv
        lda coups_fin
        sta rc_t_fin_lo,x
        lda coups_fin+1
        sta rc_t_fin_hi,x
        lda #0
        sta rc_t_coup,x             ; aucun coup legal pour l'instant
nm_boucle
        jsr choisir_meilleur_niv
        bcc nm_fini
        jsr charger_coup
        jsr jouer_interne
        jsr echec_apres_coup
        bcs nm_annuler
        ldx rc_niv
        inc rc_t_coup,x
        ; descendre d'un niveau, fenetre retournee
        lda rc_t_beta_lo,x
        sta rc_alpha_fils
        lda rc_t_beta_hi,x
        sta rc_alpha_fils+1
        jsr rc_nier_alpha_fils
        lda rc_t_alpha_lo,x
        sta rc_beta_fils
        lda rc_t_alpha_hi,x
        sta rc_beta_fils+1
        jsr rc_nier_beta_fils
        lda rc_t_prof,x
        sec
        sbc #1
        sta rc_prof_fils
        inc rc_niv
        jsr negamax
        dec rc_niv
        jsr rc_nier_score
        jsr annuler_interne
        ; alpha du niveau courant
        ldx rc_niv
        jsr rc_score_sup_alpha_niv
        bcc nm_suivant
        lda rc_score
        sta rc_t_alpha_lo,x
        lda rc_score+1
        sta rc_t_alpha_hi,x
        ; coupure beta : inutile de chercher plus loin dans cette branche
        jsr rc_alpha_atteint_beta
        bcs nm_fini
nm_suivant
        jsr temps_ecoule
        bcc +
        lda #1
        sta rc_arret
+       lda rc_arret
        bne nm_fini
        jmp nm_boucle
nm_annuler
        jsr annuler_interne
        jmp nm_suivant
nm_fini
        ldx rc_niv
        lda rc_t_coup,x
        bne nm_rendre
        ; aucun coup legal : mat si le roi est en prise, pat sinon
        lda trait
        jsr roi_en_echec
        bcc nm_pat
        jsr rc_score_mat            ; un mat d'autant meilleur qu'il est proche
        jmp nm_rendre_place
nm_pat
        lda #0
        sta rc_score
        sta rc_score+1
        jmp nm_rendre_place
nm_rendre
        ldx rc_niv
        lda rc_t_alpha_lo,x
        sta rc_score
        lda rc_t_alpha_hi,x
        sta rc_score+1
nm_rendre_place
        ldx rc_niv
        lda rc_t_deb_lo,x
        sta coups_fin
        lda rc_t_deb_hi,x
        sta coups_fin+1
        rts

; ---------------------------------------------------------------------
;  quiescence : au bout de la recherche, on ne s'arrete pas en plein
;  echange de pieces. On continue tant qu'il reste des prises, sans quoi
;  le programme croirait avoir gagne une dame alors qu'elle va etre
;  reprise au coup suivant.
; ---------------------------------------------------------------------
quiescence
        jsr evaluer
        ldx rc_niv
        ; le camp au trait n'est pas oblige de prendre : son score actuel
        ; est un plancher
        lda ev_score
        sta rc_score
        lda ev_score+1
        sta rc_score+1
        jsr rc_score_atteint_beta
        bcc qs_alpha
        lda rc_t_beta_lo,x
        sta rc_score
        lda rc_t_beta_hi,x
        sta rc_score+1
        rts
qs_alpha
        jsr rc_score_sup_alpha_niv
        bcc qs_coups
        lda rc_score
        sta rc_t_alpha_lo,x
        lda rc_score+1
        sta rc_t_alpha_hi,x
qs_coups
        ; profondeur de calme bornee : une suite de prises finit toujours,
        ; mais mieux vaut s'en assurer
        lda rc_niv
        cmp #PROF_QUIET
        bcc qs_generer
        jmp qs_rendre_alpha
qs_generer
        ldx rc_niv
        lda coups_fin
        sta rc_t_deb_lo,x
        sta ptr_liste
        lda coups_fin+1
        sta rc_t_deb_hi,x
        sta ptr_liste+1
        lda #1
        sta gc_prises_seules
        jsr generer_coups
        lda #0
        sta gc_prises_seules
        jsr noter_coups
        ldx rc_niv
        lda coups_fin
        sta rc_t_fin_lo,x
        lda coups_fin+1
        sta rc_t_fin_hi,x
qs_boucle
        jsr choisir_meilleur_niv
        bcc qs_fini
        jsr charger_coup
        jsr jouer_interne
        jsr echec_apres_coup
        bcs qs_annuler
        ldx rc_niv
        lda rc_t_beta_lo,x
        sta rc_alpha_fils
        lda rc_t_beta_hi,x
        sta rc_alpha_fils+1
        jsr rc_nier_alpha_fils
        lda rc_t_alpha_lo,x
        sta rc_beta_fils
        lda rc_t_alpha_hi,x
        sta rc_beta_fils+1
        jsr rc_nier_beta_fils
        lda #0
        sta rc_prof_fils
        inc rc_niv
        jsr negamax
        dec rc_niv
        jsr rc_nier_score
        jsr annuler_interne
        ldx rc_niv
        jsr rc_score_sup_alpha_niv
        bcc qs_suivant
        lda rc_score
        sta rc_t_alpha_lo,x
        lda rc_score+1
        sta rc_t_alpha_hi,x
        jsr rc_alpha_atteint_beta
        bcs qs_fini
qs_suivant
        jsr temps_ecoule
        bcc +
        lda #1
        sta rc_arret
+       lda rc_arret
        beq qs_boucle
        jmp qs_fini
qs_annuler
        jsr annuler_interne
        jmp qs_suivant
qs_fini
        ldx rc_niv
        lda rc_t_deb_lo,x
        sta coups_fin
        lda rc_t_deb_hi,x
        sta coups_fin+1
qs_rendre_alpha
        ldx rc_niv
        lda rc_t_alpha_lo,x
        sta rc_score
        lda rc_t_alpha_hi,x
        sta rc_score+1
        rts

; ---------------------------------------------------------------------
;  noter_coups : donne une note a chaque coup de la tranche courante,
;  pour que les plus prometteurs soient essayes en premier (une coupure
;  arrive d'autant plus tot). Ordre retenu : les prises d'abord, la plus
;  grosse piece prise par la plus petite (MVV-LVA), puis les promotions,
;  puis les coups tranquilles.
; ---------------------------------------------------------------------
noter_coups
        lda ptr_liste
        sta ptr_coup
        lda ptr_liste+1
        sta ptr_coup+1
nc_boucle
        lda ptr_coup
        cmp coups_fin
        bne nc_un
        lda ptr_coup+1
        cmp coups_fin+1
        beq nc_fin
nc_un
        ldy #1
        lda (ptr_coup),y
        tax
        lda plateau,x
        beq nc_tranquille
        and #MASQUE_TYPE
        tay
        lda valeurs_tri,y
        asl a
        asl a
        asl a
        asl a               ; la victime pese seize fois plus
        sta nc_note
        ldy #0
        lda (ptr_coup),y
        tax
        lda plateau,x
        and #MASQUE_TYPE
        tay
        lda #15
        sec
        sbc valeurs_tri,y   ; un petit preneur vaut mieux
        clc
        adc nc_note
        jmp nc_poser
nc_tranquille
        ldy #2
        lda (ptr_coup),y
        cmp #CP_PROMO
        bcs nc_promotion
        cmp #CP_EP
        beq nc_prise_ep
        lda #0
        beq nc_poser
nc_prise_ep
        lda #16+14          ; un pion pris par un pion
        bne nc_poser
nc_promotion
        lda #200
nc_poser
        ldy #3
        sta (ptr_coup),y
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc nc_boucle
        inc ptr_coup+1
        jmp nc_boucle
nc_fin
        rts

; ---------------------------------------------------------------------
;  choisir_meilleur : sort de la tranche le coup le mieux note et le
;  marque comme pris. Un tri complet couterait plus cher que ces
;  parcours, puisqu'une coupure interrompt souvent la liste des le
;  deuxieme ou troisieme coup.
;  Sortie  C = 1 et ptr_coup pointe le coup ; C = 0 si la tranche est
;          epuisee.
; ---------------------------------------------------------------------
choisir_meilleur
        lda rc_deb_rac
        sta cm_deb
        lda rc_deb_rac+1
        sta cm_deb+1
        lda rc_fin_rac
        sta cm_fin
        lda rc_fin_rac+1
        sta cm_fin+1
        jmp cm_chercher

choisir_meilleur_niv
        ldx rc_niv
        lda rc_t_deb_lo,x
        sta cm_deb
        lda rc_t_deb_hi,x
        sta cm_deb+1
        lda rc_t_fin_lo,x
        sta cm_fin
        lda rc_t_fin_hi,x
        sta cm_fin+1
cm_chercher
        lda cm_deb
        sta ptr_coup
        lda cm_deb+1
        sta ptr_coup+1
        lda #0
        sta cm_meilleur
        sta cm_trouve
cm_boucle
        lda ptr_coup
        cmp cm_fin
        bne cm_un
        lda ptr_coup+1
        cmp cm_fin+1
        beq cm_fini
cm_un
        ldy #3
        lda (ptr_coup),y
        cmp #COUP_PRIS
        beq cm_suivant
        cmp cm_meilleur
        bcc cm_suivant
        sta cm_meilleur
        lda ptr_coup
        sta cm_garde
        lda ptr_coup+1
        sta cm_garde+1
        lda #1
        sta cm_trouve
cm_suivant
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc cm_boucle
        inc ptr_coup+1
        jmp cm_boucle
cm_fini
        lda cm_trouve
        beq cm_aucun
        lda cm_garde
        sta ptr_coup
        lda cm_garde+1
        sta ptr_coup+1
        ldy #3
        lda #COUP_PRIS
        sta (ptr_coup),y    ; celui-la est servi
        sec
        rts
cm_aucun
        clc
        rts

; ---------------------------------------------------------------------
;  pousser_coup_connu : donne la meilleure note au coup que l'iteration
;  precedente avait retenu, pour qu'il soit essaye en premier.
; ---------------------------------------------------------------------
pousser_coup_connu
        lda rc_deb_rac
        sta ptr_coup
        lda rc_deb_rac+1
        sta ptr_coup+1
pcc_boucle
        lda ptr_coup
        cmp rc_fin_rac
        bne pcc_un
        lda ptr_coup+1
        cmp rc_fin_rac+1
        beq pcc_fin
pcc_un
        ldy #0
        lda (ptr_coup),y
        cmp rc_coup
        bne pcc_suivant
        iny
        lda (ptr_coup),y
        cmp rc_coup+1
        bne pcc_suivant
        iny
        lda (ptr_coup),y
        cmp rc_coup+2
        bne pcc_suivant
        ldy #3
        lda #COUP_PRIS-1    ; juste en dessous de la marque "deja servi"
        sta (ptr_coup),y
        rts
pcc_suivant
        lda ptr_coup
        clc
        adc #COUP_OCTETS
        sta ptr_coup
        bcc pcc_boucle
        inc ptr_coup+1
        jmp pcc_boucle
pcc_fin
        rts

; ---------------------------------------------------------------------
;  Arithmetique des scores, sur seize bits signes
; ---------------------------------------------------------------------
rc_nier_score
        sec
        lda #0
        sbc rc_score
        sta rc_score
        lda #0
        sbc rc_score+1
        sta rc_score+1
        rts

rc_nier_alpha_fils
        sec
        lda #0
        sbc rc_alpha_fils
        sta rc_alpha_fils
        lda #0
        sbc rc_alpha_fils+1
        sta rc_alpha_fils+1
        rts

rc_nier_beta_fils
        sec
        lda #0
        sbc rc_beta_fils
        sta rc_beta_fils
        lda #0
        sbc rc_beta_fils+1
        sta rc_beta_fils+1
        rts

; rc_score_sup_alpha : rc_score > rc_alpha ? C = 1 si oui
rc_score_sup_alpha
        lda rc_alpha
        cmp rc_score
        lda rc_alpha+1
        sbc rc_score+1
        bvc +
        eor #$80
+       bmi rc_vrai
        clc
        rts
rc_vrai
        sec
        rts

; rc_score_sup_alpha_niv : idem, contre l'alpha du niveau X
rc_score_sup_alpha_niv
        lda rc_t_alpha_lo,x
        cmp rc_score
        lda rc_t_alpha_hi,x
        sbc rc_score+1
        bvc +
        eor #$80
+       bmi rc_vrai
        clc
        rts

; rc_score_atteint_beta : rc_score >= beta du niveau X ? C = 1 si oui
rc_score_atteint_beta
        lda rc_score
        cmp rc_t_beta_lo,x
        lda rc_score+1
        sbc rc_t_beta_hi,x
        bvc +
        eor #$80
+       bmi +
        sec
        rts
+       clc
        rts

; rc_alpha_atteint_beta : alpha >= beta au niveau X ? C = 1 si oui
rc_alpha_atteint_beta
        lda rc_t_alpha_lo,x
        cmp rc_t_beta_lo,x
        lda rc_t_alpha_hi,x
        sbc rc_t_beta_hi,x
        bvc +
        eor #$80
+       bmi +
        sec
        rts
+       clc
        rts

; rc_score_mat : etre mat au niveau rc_niv vaut -MAT_SCORE + niveau,
; pour qu'un mat lointain soit prefere a un mat immediat quand on le subit
rc_score_mat
        lda #<(-MAT_SCORE)
        clc
        adc rc_niv
        sta rc_score
        lda #>(-MAT_SCORE)
        adc #0
        sta rc_score+1
        rts

; ---------------------------------------------------------------------
;  temps_ecoule : le temps accorde au niveau est-il depasse, ou le
;  joueur a-t-il appuye sur STOP ? Sortie C = 1 si on doit s'arreter.
; ---------------------------------------------------------------------
temps_ecoule
        inc rc_compteur
        lda rc_compteur
        and #$07
        beq te_regarder     ; un noeud sur huit : l'horloge coute cher
        clc
        rts
te_regarder
        jsr GETIN
        beq te_horloge
        cmp #TOUCHE_STOP
        beq te_stop
        ; une touche tapee pendant la reflexion : on la met de cote
        ; plutot que de la perdre, la boucle principale la traitera
        jsr ranger_touche
        jmp te_horloge
te_stop
        lda #1
        sta rc_arret
        sec
        rts
te_horloge
        ; jiffies ecoules depuis le depart, sur seize bits
        sec
        lda TI_BAS
        sbc rc_depart
        sta rc_ecoule
        lda TI_MOYEN
        sbc rc_depart+1
        sta rc_ecoule+1
        lda rc_ecoule+1
        cmp rc_limite+1
        bcc te_non
        bne te_oui
        lda rc_ecoule
        cmp rc_limite
        bcc te_non
te_oui
        sec
        rts
te_non
        clc
        rts

; ---------------------------------------------------------------------
;  alea : suite pseudo-aleatoire, un registre a decalage boucle
; ---------------------------------------------------------------------
alea
        lda rc_alea
        asl a
        bcc +
        eor #$1D
+       sta rc_alea
        rts

; ---------------------------------------------------------------------
;  Tampon des touches tapees pendant la reflexion de l'ordinateur
;
;  temps_ecoule lit le clavier pour reconnaitre STOP, ce qui consomme
;  aussi les touches du joueur. Plutot que de les perdre, on les range
;  ici ; la boucle principale les sert avant de relire le clavier.
; ---------------------------------------------------------------------
ranger_touche
        ldx rc_nb_touches
        cpx #TOUCHES_MAX
        bcs rt_plein
        ldy rc_tampon_e
        sta rc_tampon,y
        iny
        tya
        and #TOUCHES_MAX-1
        sta rc_tampon_e
        inc rc_nb_touches
rt_plein
        rts

; prendre_touche : A = la plus ancienne touche en attente, 0 s'il n'y en
; a pas ; Z le dit.
prendre_touche
        lda rc_nb_touches
        beq pt_vide
        dec rc_nb_touches
        ldy rc_tampon_s
        lda rc_tampon,y
        pha
        tya
        clc
        adc #1
        and #TOUCHES_MAX-1
        sta rc_tampon_s
        pla
        rts
pt_vide
        lda #0
        rts
