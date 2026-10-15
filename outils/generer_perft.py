#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Produit donnees_perft.asm (positions de test) et les valeurs attendues.

Les positions sont les classiques de la validation d'un generateur de
coups : la position initiale, puis quatre positions qui mettent a
l'epreuve le roque, la prise en passant et la promotion. Les nombres
attendus sont recalcules ici par python-chess, l'oracle, plutot que
recopies a la main.

Usage :  python3 outils/generer_perft.py
"""

import json
import os
import sys

import chess

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (nom, FEN, profondeur maximale demandee au 6502)
POSITIONS = [
    ("initiale",
     "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 4),
    ("kiwipete",
     "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 3),
    ("finale",
     "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 4),
    ("promotions",
     "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 3),
    ("encombree",
     "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 0 1", 3),
]

# Encodage d'une case, identique a constantes.asm
TYPES = {chess.PAWN: 1, chess.KNIGHT: 2, chess.BISHOP: 3,
         chess.ROOK: 4, chess.QUEEN: 5, chess.KING: 6}
NOIR = 8

ROQUE_BP, ROQUE_BG, ROQUE_NP, ROQUE_NG = 1, 2, 4, 8


def octets_plateau(board):
    """Les 64 cases, rangee 1 d'abord, colonne A d'abord."""
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
        d |= ROQUE_BP
    if board.has_queenside_castling_rights(chess.WHITE):
        d |= ROQUE_BG
    if board.has_kingside_castling_rights(chess.BLACK):
        d |= ROQUE_NP
    if board.has_queenside_castling_rights(chess.BLACK):
        d |= ROQUE_NG
    return d


def case_ep(board):
    """La case traversee, en index 0x88 ; $FF s'il n'y en a pas.

    python-chess garde la case meme quand aucun pion ne peut prendre ;
    le generateur 6502 fait pareil, puisqu'il verifie la prise au moment
    de la produire.
    """
    if board.ep_square is None:
        return 0xFF
    return (chess.square_rank(board.ep_square) * 16
            + chess.square_file(board.ep_square))


def main():
    lignes = [
        "; =====================================================================",
        ";  donnees_perft.asm - positions de validation du generateur de coups",
        ";",
        ";  FICHIER GENERE par outils/generer_perft.py : ne pas editer a la main.",
        ";  Chaque position tient sur 64 octets de plateau (rangee 1 en tete,",
        ";  colonne A en tete), plus le trait, les droits de roque, la case de",
        ";  prise en passant et la profondeur a explorer.",
        "; =====================================================================",
        "",
    ]
    attendus = []
    noms = []
    plateaux = []
    traits, roques, eps, profs = [], [], [], []

    for nom, fen, prof in POSITIONS:
        board = chess.Board(fen)
        noms.append(nom)
        plateaux.append(octets_plateau(board))
        traits.append(0 if board.turn == chess.WHITE else NOIR)
        roques.append(droits(board))
        eps.append(case_ep(board))
        profs.append(prof)
        valeurs = [perft(board, p) for p in range(1, prof + 1)]
        attendus.append({"nom": nom, "fen": fen, "perft": valeurs})
        print("%-12s %s" % (nom, " ".join(str(v) for v in valeurs)))

    lignes.append("PERFT_NB    = %d" % len(POSITIONS))
    lignes.append("")
    lignes.append("perft_plateaux")
    for nom, cases in zip(noms, plateaux):
        lignes.append("        ; %s" % nom)
        for r in range(8):
            rangee = cases[r * 8:(r + 1) * 8]
            lignes.append("        .byte " + ", ".join("%d" % v for v in rangee))
    lignes.append("")
    lignes.append("perft_traits")
    lignes.append("        .byte " + ", ".join(str(v) for v in traits))
    lignes.append("perft_roques")
    lignes.append("        .byte " + ", ".join(str(v) for v in roques))
    lignes.append("perft_ep")
    lignes.append("        .byte " + ", ".join("$%02X" % v for v in eps))
    lignes.append("perft_profondeurs")
    lignes.append("        .byte " + ", ".join(str(v) for v in profs))
    lignes.append("")

    chemin = os.path.join(RACINE, "donnees_perft.asm")
    with open(chemin, "w") as f:
        f.write("\n".join(lignes) + "\n")
    ref = os.path.join(RACINE, "outils", "perft_attendu.json")
    with open(ref, "w") as f:
        json.dump(attendus, f, indent=2)
    print("ecrit %s et %s" % (chemin, ref))
    return 0


def perft(board, profondeur):
    if profondeur == 0:
        return 1
    if profondeur == 1:
        return board.legal_moves.count()
    total = 0
    for coup in board.legal_moves:
        board.push(coup)
        total += perft(board, profondeur - 1)
        board.pop()
    return total


if __name__ == "__main__":
    sys.exit(main())
