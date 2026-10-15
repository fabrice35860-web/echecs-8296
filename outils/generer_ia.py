#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Produit donnees_ia.asm : positions ou le bon coup ne fait aucun doute.

Ce sont des positions de test pour l'adversaire, pas pour le generateur
de coups (celui-la, c'est perft qui le juge). Chacune n'a qu'un coup
raisonnable : un mat en un, une reprise obligee, une piece a sauver.
Un moteur qui se trompe la-dessus a un defaut dans sa recherche ou dans
son evaluation.

Les coups attendus sont verifies legaux par python-chess avant d'etre
ecrits ; leur bien-fonde, lui, reste un jugement d'echiquier.

Usage :  python3 outils/generer_ia.py
"""

import json
import os
import sys

import chess

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (nom, FEN, niveau, coups acceptes en notation "depart-arrivee", commentaire)
POSITIONS = [
    ("mat du couloir", "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", 2,
     ["a1-a8"], "la tour mate au fond ; tout autre coup laisse gagner"),
    ("mat en un de la dame", "6k1/5ppp/8/8/8/8/5PPP/3Q2K1 w - - 0 1", 2,
     ["d1-d8"], "meme idee avec la dame"),
    ("reprendre la dame", "4k3/8/8/3q4/3Q4/8/8/4K3 w - - 0 1", 2,
     ["d4-d5"], "les dames se regardent : il faut prendre"),
    ("sauver la dame", "4k3/8/8/8/3q4/8/3R4/4K3 b - - 0 1", 3,
     "SAUVER_DAME",
     "la dame est attaquee par la tour : elle prend ou se met a l'abri"),
    # Le roi noir est hors du carre du pion : la prise gagne pour de bon,
    # a n'importe quelle profondeur. Avec le roi en e8 la course est
    # tenable et le moteur a raison de jouer autre chose -- la position
    # jugeait alors la profondeur, pas le moteur.
    ("gagner un pion franc", "7k/8/8/3p4/4P3/8/8/K7 w - - 0 1", 3,
     ["e4-d5"], "le pion d5 est libre et le roi noir trop loin"),
    ("promouvoir tout de suite", "8/4P3/5k2/8/8/8/8/4K3 w - - 0 1", 3,
     ["e7-e8"], "attendre laisse le roi noir revenir en e7"),
]

TYPES = {chess.PAWN: 1, chess.KNIGHT: 2, chess.BISHOP: 3,
         chess.ROOK: 4, chess.QUEEN: 5, chess.KING: 6}
NOIR = 8
ROQUE = {"K": 1, "Q": 2, "k": 4, "q": 8}


def octets_plateau(board):
    cases = []
    for rangee in range(8):
        for colonne in range(8):
            piece = board.piece_at(chess.square(colonne, rangee))
            if piece is None:
                cases.append(0)
            else:
                v = TYPES[piece.piece_type]
                if piece.color == chess.BLACK:
                    v |= NOIR
                cases.append(v)
    return cases


def droits(board):
    d = 0
    if board.has_kingside_castling_rights(chess.WHITE):
        d |= ROQUE["K"]
    if board.has_queenside_castling_rights(chess.WHITE):
        d |= ROQUE["Q"]
    if board.has_kingside_castling_rights(chess.BLACK):
        d |= ROQUE["k"]
    if board.has_queenside_castling_rights(chess.BLACK):
        d |= ROQUE["q"]
    return d


def case_ep(board):
    if board.ep_square is None:
        return 0xFF
    return (chess.square_rank(board.ep_square) * 16
            + chess.square_file(board.ep_square))


def coups_qui_sauvent_la_dame(board):
    """Les coups apres lesquels la dame du camp au trait n'est plus prise.

    Les enumerer ici plutot que de les recopier evite de se tromper : la
    liste suit la position, et le test ne juge que ce qui compte, a
    savoir que l'ordinateur ne laisse pas sa dame se faire manger.
    """
    camp = board.turn
    sauves = []
    for coup in board.legal_moves:
        board.push(coup)
        dames = list(board.pieces(chess.QUEEN, camp))
        if not dames:
            board.pop()
            continue
        if not any(board.is_attacked_by(not camp, c) for c in dames):
            sauves.append(chess.square_name(coup.from_square) + "-"
                          + chess.square_name(coup.to_square))
        board.pop()
    return sauves


def main():
    lignes = [
        "; =====================================================================",
        ";  donnees_ia.asm - positions de test de l'adversaire",
        ";",
        ";  FICHIER GENERE par outils/generer_ia.py : ne pas editer a la main.",
        "; =====================================================================",
        "",
    ]
    attendus = []
    plateaux, traits, roques, eps, niveaux = [], [], [], [], []

    for nom, fen, niv, coups, pourquoi in POSITIONS:
        board = chess.Board(fen)
        if coups == "SAUVER_DAME":
            coups = coups_qui_sauvent_la_dame(board)
            print("%-30s %d coups acceptes" % (nom, len(coups)))
        legaux = set()
        for coup in board.legal_moves:
            legaux.add(chess.square_name(coup.from_square) + "-"
                       + chess.square_name(coup.to_square))
        for c in coups:
            if c not in legaux:
                print("ERREUR : %s n'est pas legal dans %s" % (c, nom))
                return 1
        plateaux.append(octets_plateau(board))
        traits.append(0 if board.turn == chess.WHITE else NOIR)
        roques.append(droits(board))
        eps.append(case_ep(board))
        niveaux.append(niv)
        attendus.append({"nom": nom, "fen": fen, "niveau": niv,
                         "coups": coups, "pourquoi": pourquoi})
        print("%-30s %s" % (nom, " ou ".join(coups[:4])
                            + (" ..." if len(coups) > 4 else "")))

    lignes.append("IA_NB       = %d" % len(POSITIONS))
    lignes.append("")
    lignes.append("ia_plateaux")
    for (nom, _, _, _, _), cases in zip(POSITIONS, plateaux):
        lignes.append("        ; %s" % nom)
        for r in range(8):
            lignes.append("        .byte " + ", ".join(
                "%d" % v for v in cases[r * 8:(r + 1) * 8]))
    lignes.append("")
    lignes.append("ia_traits")
    lignes.append("        .byte " + ", ".join(str(v) for v in traits))
    lignes.append("ia_roques")
    lignes.append("        .byte " + ", ".join(str(v) for v in roques))
    lignes.append("ia_ep")
    lignes.append("        .byte " + ", ".join("$%02X" % v for v in eps))
    lignes.append("ia_niveaux")
    lignes.append("        .byte " + ", ".join(str(v) for v in niveaux))
    lignes.append("")

    chemin = os.path.join(RACINE, "donnees_ia.asm")
    with open(chemin, "w") as f:
        f.write("\n".join(lignes) + "\n")
    ref = os.path.join(RACINE, "outils", "ia_attendu.json")
    with open(ref, "w") as f:
        json.dump(attendus, f, indent=2)
    print("ecrit %s et %s" % (chemin, ref))
    return 0


if __name__ == "__main__":
    sys.exit(main())
