import io

import chess.pgn
import pyperclip
import requests

# URL of the View PGN page for the game
URL = "https://www.chessgames.com/nodejs/game/viewGamePGN?text=1&gid=1018910"

# Get the PGN and parse it
pgn = requests.get(URL).text
game = chess.pgn.read_game(io.StringIO(pgn))
board = game.board()

# Get the UCI moves
uci_moves = []
for move in game.mainline_moves():
    uci_moves.append(move.uci())
    board.push(move)

result_str = ", ".join([f"\'{move}\'" for move in uci_moves])

print(result_str)
pyperclip.copy(result_str)