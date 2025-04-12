import socket
import threading

HOST = '127.0.0.1'
PORT = 65432
ROLE = 'white'  # or 'black'


def listen_to_server(sock):
    while True:
        try:
            data = sock.recv(1024)
            if not data:
                break
            msg = data.decode().strip()
            # Clear current input line, print the message, reprint prompt
            print(f"\n[{ROLE}] Received from server: {msg}")
            print(f"[{ROLE}] Input move: ", end='', flush=True)
        except ConnectionResetError:
            print(f"\n[{ROLE}] Connection lost.")
            break


def choose_move() -> str:
    return input(f"[{ROLE}] Input move: ").strip()


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((HOST, PORT))
        print(f"[{ROLE}] Connected to server.")

        # Send role to the server
        s.sendall(f"{ROLE}\n".encode())

        # Start listener thread
        threading.Thread(target=listen_to_server, args=(s,), daemon=True).start()

        while True:
            try:
                move = choose_move()
                if move == "":
                    continue
                s.sendall((move + "\n").encode())
            except (EOFError, KeyboardInterrupt):
                print("\n[!] Exiting.")
                break


if __name__ == "__main__":
    main()
