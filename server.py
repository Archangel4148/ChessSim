import socket
import threading

HOST = '127.0.0.1'
PORT = 65432

clients = {}
lock = threading.Lock()


def handle_client(conn, addr):
    print(f"[+] New connection from {addr}")
    role = conn.recv(1024).decode().strip()
    with lock:
        clients[role] = conn
    print(f"[+] Registered {addr} as {role}")

    try:
        while True:
            data = conn.recv(1024)
            if not data:
                break
            message = data.decode().strip()
            print(f"[{role}] sent: {message}")

            with lock:
                # Handle invalid responses from clients (Godot)
                if message.startswith("INVALID:"):
                    # Format: INVALID:<uci>:<target_role>
                    try:
                        _, uci, target_role = message.split(":")
                        target_conn = clients.get(target_role)
                        if target_conn:
                            target_conn.sendall(f"INVALID:{uci}\n".encode())
                            print(f"[!] Sent INVALID to {target_role} for move {uci}")
                    except ValueError:
                        print("[!] Malformed INVALID message")
                    continue  # Don't broadcast INVALIDs

                elif message.startswith("OUTOFTURN:"):
                    try:
                        _, target_role = message.split(":")
                        target_conn = clients.get(target_role)
                        if target_conn:
                            target_conn.sendall(f"OUTOFTURN\n".encode())
                            print(f"[!] Sent OUTOFTURN to {target_role}")
                    except ValueError:
                        print("[!] Malformed OUTOFTURN message")
                    continue  # Don't broadcast OUTOFTURNs

                # Broadcast the move to all clients
                for r, c in clients.items():
                    if c != conn:
                        c.sendall(f"{role}:{message}\n".encode())
    except ConnectionResetError:
        print(f"[!] {role} disconnected")
    finally:
        with lock:
            if role in clients:
                del clients[role]
        conn.close()


server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind((HOST, PORT))
server.listen()
print(f"[*] Server listening on {HOST}:{PORT}")

try:
    while True:
        conn, addr = server.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()
except KeyboardInterrupt:
    print("\n[!] Shutting down server")
finally:
    server.close()
