import stockfish

from bot_client import ChessBot


class StockfishBot(ChessBot):

    def __init__(self, role, host='127.0.0.1', port=65432):
        super().__init__(role, host, port)
        self.stockfish = stockfish.Stockfish(
            path="stockfish-windows-x86-64-avx2/stockfish/stockfish-windows-x86-64-avx2.exe",
            parameters={
                "Skill Level": 20,
                "Threads": 3,
                "Hash": 64,
            }
        )

    def choose_move(self) -> str:
        print("Choosing Move!")
        self.stockfish.set_fen_position(self.current_fen)
        move = self.stockfish.get_best_move_time(500)
        print("Move:", move)
        return move


if __name__ == '__main__':
    bot = StockfishBot("white")
    bot.start()
