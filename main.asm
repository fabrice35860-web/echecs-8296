; =====================================================================
;  Jeu d'echecs pour Commodore 8296
;  main.asm - amorce BASIC, initialisation et boucle principale
;
;  Etape 1 : affichage complet (echiquier plein ecran, pieces en quarts de
;  bloc, panneau, curseur) et deplacement libre des pieces, sans les
;  regles. Les etapes suivantes greffent le generateur de coups puis la
;  recherche.
;
;  Assemblage :  64tass --cbm-prg -o echecs.prg main.asm
;  Lancement  :  LOAD"ECHECS",8  puis  RUN
; =====================================================================

.include "constantes.asm"

; ---------------------------------------------------------------------
;  Amorce BASIC : 10 SYS1040 ($0410)
; ---------------------------------------------------------------------
* = $0401
        .word basic_fin     ; lien vers la ligne suivante
        .word 10            ; numero de ligne
        .byte $9E           ; token SYS
        .text "1040"
        .byte 0             ; fin de ligne
basic_fin
        .word 0             ; fin de programme
        .fill $0410-*, 0    ; bourrage jusqu'au point d'entree

; ---------------------------------------------------------------------
;  Point d'entree
; ---------------------------------------------------------------------
* = $0410
debut
        jsr sauver_pz
        ; le jeu de caracteres d'abord : tout l'affichage en depend
        jsr detecter_rom
        jsr appliquer_rom
depuis_choix_rom
        jsr choix_rom
        jsr init_ecran
        jsr afficher_fixes
        jsr nouvelle_partie

; ---------------------------------------------------------------------
;  Boucle principale : battement du curseur puis lecture du clavier
; ---------------------------------------------------------------------
boucle
        jsr tour_ordinateur
        jsr clignoter
        ; les touches tapees pendant la reflexion de l'ordinateur ont ete
        ; mises de cote : elles passent avant le clavier
        jsr prendre_touche
        bne bc_touche
        jsr GETIN
        beq bc_suite
bc_touche
        jsr traiter_touche
bc_suite
        lda retour_menu
        beq bc_fin_test
        lda #0
        sta retour_menu
        jmp depuis_choix_rom
bc_fin_test
        lda demande_fin
        beq boucle

; ---------------------------------------------------------------------
;  Sortie : on rend la machine dans l'etat ou on l'a trouvee
; ---------------------------------------------------------------------
        jsr rendre_pz
        lda #MODE_MINUS
        sta REG_CARACT
        ; on passe par l'editeur plutot que d'effacer la RAM ecran a la
        ; main : cela replace aussi son curseur, sans quoi le BASIC
        ; ecrirait son "ready." n'importe ou.
        lda #PET_EFFACER
        jsr CHROUT
        rts                 ; retour au BASIC (SYS a empile l'adresse)

; ---------------------------------------------------------------------
;  redessiner_tout : remet tout l'ecran de jeu en place
;  Sert au retour de l'ecran d'aide.
; ---------------------------------------------------------------------
redessiner_tout
        jsr init_ecran
        jsr afficher_fixes
        jsr dessiner_echiquier
        jsr maj_panneau
        jsr maj_pendule
        jsr afficher_notation
        jsr afficher_prises
        jsr maj_saisie
        lda selection
        bmi rt_sans_choix
        jsr marquer_destinations
        jmp message_selection
rt_sans_choix
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp message_trait

; ---------------------------------------------------------------------
;  sauver_pz / rendre_pz : emprunt de la fin de la page zero
; ---------------------------------------------------------------------
sauver_pz
        ldx #PZ_NOMBRE-1
-       lda PZ_BASE,x
        sta sauvegarde_pz,x
        dex
        bpl -
        rts

rendre_pz
        ldx #PZ_NOMBRE-1
-       lda sauvegarde_pz,x
        sta PZ_BASE,x
        dex
        bpl -
        rts

; ---------------------------------------------------------------------
;  Modules
; ---------------------------------------------------------------------
.include "ecran.asm"
.include "ecran_rom.asm"
.include "clavier.asm"
.include "coups.asm"
.include "regles.asm"
.include "evaluation.asm"
.include "recherche.asm"
.include "donnees.asm"
.include "donnees_tables.asm"
.include "donnees_pieces.asm"
.include "donnees_eval.asm"

; ---------------------------------------------------------------------
;  Garde-fou : le programme et ses donnees ne doivent pas rattraper les
;  zones de travail, qui sont a adresse fixe. Une collision silencieuse
;  abime le plateau en pleine partie, et c'est fort desagreable a
;  diagnostiquer.
; ---------------------------------------------------------------------
.cerror * > DEBUT_ZONES, "le programme deborde sur les zones de travail"
