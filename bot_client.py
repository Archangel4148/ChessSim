import socket
import threading


class ChessBot:
    def __init__(self, role, host='127.0.0.1', port=65432):
        self.role = role
        self.host = host
        self.port = port
        self.sock = None
        self.current_fen = None

    def listen_to_server(self):
        while True:
            try:
                data = self.sock.recv(1024)
                if not data:
                    break
                msg = data.decode().strip()
                if msg.startswith("FEN:"):
                    self.current_fen = msg[4:]
                print(f"\n[{self.role}] Received from server: {msg}")
                if msg.startswith("TURN"):
                    move = ""
                    while not move:
                        move = self.choose_move()
                    self.sock.sendall((move + "\n").encode())

            except ConnectionResetError:
                print(f"\n[{self.role}] Connection lost.")
                break

    def choose_move(self) -> str:
        """Override this in subclasses for bot logic (e.g., Stockfish)"""
        return input(f"[{self.role}] Input move: ").strip()

    def start(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as self.sock:
            self.sock.connect((self.host, self.port))
            print(f"[{self.role}] Connected to server.")
            self.sock.sendall(f"{self.role}\n".encode())

            thread = threading.Thread(target=self.listen_to_server)
            thread.start()
            thread.join()  # Block here until listener exits


if __name__ == '__main__':
    bot = ChessBot("black")
    bot.start()
