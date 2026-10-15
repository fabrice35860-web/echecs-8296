; =====================================================================
;  donnees_perft.asm - positions de validation du generateur de coups
;
;  FICHIER GENERE par outils/generer_perft.py : ne pas editer a la main.
;  Chaque position tient sur 64 octets de plateau (rangee 1 en tete,
;  colonne A en tete), plus le trait, les droits de roque, la case de
;  prise en passant et la profondeur a explorer.
; =====================================================================

PERFT_NB    = 5

perft_plateaux
        ; initiale
        .byte 4, 2, 3, 5, 6, 3, 2, 4
        .byte 1, 1, 1, 1, 1, 1, 1, 1
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 9, 9, 9, 9, 9, 9, 9, 9
        .byte 12, 10, 11, 13, 14, 11, 10, 12
        ; kiwipete
        .byte 4, 0, 0, 0, 6, 0, 0, 4
        .byte 1, 1, 1, 3, 3, 1, 1, 1
        .byte 0, 0, 2, 0, 0, 5, 0, 9
        .byte 0, 9, 0, 0, 1, 0, 0, 0
        .byte 0, 0, 0, 1, 2, 0, 0, 0
        .byte 11, 10, 0, 0, 9, 10, 9, 0
        .byte 9, 0, 9, 9, 13, 9, 11, 0
        .byte 12, 0, 0, 0, 14, 0, 0, 12
        ; finale
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 1, 0, 1, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 4, 0, 0, 0, 9, 0, 14
        .byte 6, 1, 0, 0, 0, 0, 0, 12
        .byte 0, 0, 0, 9, 0, 0, 0, 0
        .byte 0, 0, 9, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        ; promotions
        .byte 4, 0, 0, 5, 0, 4, 6, 0
        .byte 1, 9, 0, 1, 0, 0, 1, 1
        .byte 13, 0, 0, 0, 0, 2, 0, 0
        .byte 3, 3, 1, 0, 1, 0, 0, 0
        .byte 10, 1, 0, 0, 0, 0, 0, 0
        .byte 0, 11, 0, 0, 0, 10, 11, 2
        .byte 1, 9, 9, 9, 0, 9, 9, 9
        .byte 12, 0, 0, 0, 14, 0, 0, 12
        ; encombree
        .byte 4, 2, 3, 5, 6, 0, 0, 4
        .byte 1, 1, 1, 0, 2, 10, 1, 1
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 3, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 9, 0, 0, 0, 0, 0
        .byte 9, 9, 0, 1, 11, 9, 9, 9
        .byte 12, 10, 11, 13, 0, 14, 0, 12

perft_traits
        .byte 0, 0, 0, 0, 0
perft_roques
        .byte 15, 15, 0, 12, 3
perft_ep
        .byte $FF, $FF, $FF, $FF, $FF
perft_profondeurs
        .byte 4, 3, 4, 3, 3

