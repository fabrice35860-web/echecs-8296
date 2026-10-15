; =====================================================================
;  donnees_eval.asm - valeurs des pieces et tables de position
;
;  FICHIER GENERE par outils/generer_eval.py : ne pas editer a la main.
;  Les tables sont en index 0x88 : les huit octets de bourrage de
;  chaque rangee ne servent pas, mais evitent toute conversion dans la
;  boucle d'evaluation. Elles valent pour les Blancs ; les Noirs lisent
;  la meme table a l'index case EOR $70.
; =====================================================================

; --- valeur des pieces, en centipions -------------------------------
valeurs_lo
        .byte 0, <100, <320, <330, <500, <900, <0
valeurs_hi
        .byte 0, >100, >320, >330, >500, >900, >0

; Valeur approchee pour le tri des prises (MVV-LVA), en
; pions : elle tient alors sur quatre bits. Le roi vaut plus
; que la dame : c'est le plus mauvais des preneurs.
valeurs_tri
        .byte 0, 1, 3, 3, 5, 9, 10

eval_pion
        .char   0,   0,   0,   0,   0,   0,   0,   0    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   5,  10,  10, -20, -20,  10,  10,   5    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   5,  -5, -10,   0,   0, -10,  -5,   5    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   0,   0,   0,  20,  20,   0,   0,   0    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   5,   5,  10,  25,  25,  10,   5,   5    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  10,  10,  20,  30,  30,  20,  10,  10    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  50,  50,  50,  50,  50,  50,  50,  50    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   0,   0,   0,   0,   0,   0,   0,   0    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_cavalier
        .char -50, -40, -30, -30, -30, -30, -40, -50    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -40, -20,   0,   5,   5,   0, -20, -40    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30,   5,  10,  15,  15,  10,   5, -30    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30,   0,  15,  20,  20,  15,   0, -30    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30,   5,  15,  20,  20,  15,   5, -30    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30,   0,  10,  15,  15,  10,   0, -30    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -40, -20,   0,   0,   0,   0, -20, -40    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -50, -40, -30, -30, -30, -30, -40, -50    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_fou
        .char -20, -10, -10, -10, -10, -10, -10, -20    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   5,   0,   0,   0,   0,   5, -10    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,  10,  10,  10,  10,  10,  10, -10    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,  10,  10,  10,  10,   0, -10    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   5,   5,  10,  10,   5,   5, -10    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,   5,  10,  10,   5,   0, -10    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,   0,   0,   0,   0,   0, -10    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -20, -10, -10, -10, -10, -10, -10, -20    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_tour
        .char   0,   0,   0,   5,   5,   0,   0,   0    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   0,   0,   0,   0,   0,  -5    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   0,   0,   0,   0,   0,  -5    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   0,   0,   0,   0,   0,  -5    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   0,   0,   0,   0,   0,  -5    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   0,   0,   0,   0,   0,  -5    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   5,  10,  10,  10,  10,  10,  10,   5    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   0,   0,   0,   0,   0,   0,   0,   0    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_dame
        .char -20, -10, -10,  -5,  -5, -10, -10, -20    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,   5,   0,   0,   0,   0, -10    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   5,   5,   5,   5,   5,   0, -10    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char   0,   0,   5,   5,   5,   5,   0,  -5    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  -5,   0,   5,   5,   5,   5,   0,  -5    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,   5,   5,   5,   5,   0, -10    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10,   0,   0,   0,   0,   0,   0, -10    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -20, -10, -10,  -5,  -5, -10, -10, -20    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_roi
        .char  20,  30,  10,   0,   0,  10,  30,  20    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char  20,  20,   0,   0,   0,   0,  20,  20    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -10, -20, -20, -20, -20, -20, -20, -10    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -20, -30, -30, -40, -40, -30, -30, -20    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -40, -40, -50, -50, -40, -40, -30    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -40, -40, -50, -50, -40, -40, -30    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -40, -40, -50, -50, -40, -40, -30    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -40, -40, -50, -50, -40, -40, -30    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

eval_roi_finale
        .char -50, -30, -30, -30, -30, -30, -30, -50    ; rangee 1
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -30,   0,   0,   0,   0, -30, -30    ; rangee 2
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -10,  20,  30,  30,  20, -10, -30    ; rangee 3
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -10,  30,  40,  40,  30, -10, -30    ; rangee 4
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -10,  30,  40,  40,  30, -10, -30    ; rangee 5
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -10,  20,  30,  30,  20, -10, -30    ; rangee 6
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -30, -20, -10,   0,   0, -10, -20, -30    ; rangee 7
        .char 0, 0, 0, 0, 0, 0, 0, 0
        .char -50, -40, -30, -20, -20, -30, -40, -50    ; rangee 8
        .char 0, 0, 0, 0, 0, 0, 0, 0

; Adresse de la table de chaque type de piece, indexee par
; le type (1 a 6) ; l'entree 0 ne sert pas.
eval_tables_lo
        .byte 0, <eval_pion, <eval_cavalier, <eval_fou, <eval_tour, <eval_dame, <eval_roi
eval_tables_hi
        .byte 0, >eval_pion, >eval_cavalier, >eval_fou, >eval_tour, >eval_dame, >eval_roi

