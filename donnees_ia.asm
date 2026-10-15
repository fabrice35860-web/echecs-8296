; =====================================================================
;  donnees_ia.asm - positions de test de l'adversaire
;
;  FICHIER GENERE par outils/generer_ia.py : ne pas editer a la main.
; =====================================================================

IA_NB       = 6

ia_plateaux
        ; mat du couloir
        .byte 4, 0, 0, 0, 0, 0, 6, 0
        .byte 0, 0, 0, 0, 0, 1, 1, 1
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 9, 9, 9
        .byte 0, 0, 0, 0, 0, 0, 14, 0
        ; mat en un de la dame
        .byte 0, 0, 0, 5, 0, 0, 6, 0
        .byte 0, 0, 0, 0, 0, 1, 1, 1
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 9, 9, 9
        .byte 0, 0, 0, 0, 0, 0, 14, 0
        ; reprendre la dame
        .byte 0, 0, 0, 0, 6, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 5, 0, 0, 0, 0
        .byte 0, 0, 0, 13, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 14, 0, 0, 0
        ; sauver la dame
        .byte 0, 0, 0, 0, 6, 0, 0, 0
        .byte 0, 0, 0, 4, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 13, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 14, 0, 0, 0
        ; gagner un pion franc
        .byte 6, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 1, 0, 0, 0
        .byte 0, 0, 0, 9, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 14
        ; promouvoir tout de suite
        .byte 0, 0, 0, 0, 6, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 14, 0, 0
        .byte 0, 0, 0, 0, 1, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0

ia_traits
        .byte 0, 0, 0, 8, 0, 0
ia_roques
        .byte 0, 0, 0, 0, 0, 0
ia_ep
        .byte $FF, $FF, $FF, $FF, $FF, $FF
ia_niveaux
        .byte 2, 2, 2, 3, 3, 3

