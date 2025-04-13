import io

import chess.pgn
import pyperclip
import requests

# # URL of the View PGN page for the game
# URL = "https://lichess.org/TFCUa3WT"
#
# # Get the PGN and parse it
# pgn = requests.get(URL).text

pgn = """
[Event "Casual bullet game"]
[Site "https://lichess.org/FSTVKTB1"]
[Date "2022.01.17"]
[White "MrJoshie333"]
[Black "TheMadMensch"]
[Result "0-1"]
[GameId "FSTVKTB1"]
[UTCDate "2022.01.17"]
[UTCTime "20:27:28"]
[WhiteElo "1959"]
[BlackElo "2113"]
[Variant "Standard"]
[TimeControl "30+0"]
[ECO "D06"]
[Opening "Queen's Gambit"]
[Termination "Normal"]

1. d4 d5 2. c4 Bd7 3. Nf3 c6 4. e3 Qc8 5. Bd3 dxc4 6. Ke2 g6 7. Bxc4 f6 8. Re1 Bg7 9. Kf1 Nh6 10. Kg1 Rg8 11. Nbd2 Rh8 12. e4 Kd8 13. Qb3 b6 14. e5 Kc7 15. d5 Kb7 16. dxc6+ Nxc6 17. Bd5 fxe5 18. Bxc6+ Bxc6 19. Ne4 Nf5 20. Bg5 Nd4 21. Qc4 e6 22. Qxe6 Bxe4 23. Qc4 Qxc4 24. Rac1 Qd3 25. Red1 Qa6 26. Be7 Rhe8 27. Bd6 Nxf3+ 28. gxf3 Rac8 29. Rc7+ Rxc7 30. Bxc7 Kxc7 31. fxe4 Rd8 32. Rf1 Rd2 33. Kg2 Qe2 34. Kg3 Rd3+ 35. Kg2 Qg4+ 36. Kh1 Qh3 37. Kg1 Bh6 38. Kh1 Bf4 39. Kg1 Qxh2# 0-1





"""



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