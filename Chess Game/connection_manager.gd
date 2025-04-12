extends Node

signal move_received(uci_move: String)

var client := StreamPeerTCP.new()
var connected := false
var buffer := PackedByteArray()

func connect_to_bot(ip: String = "127.0.0.1", port: int = 65432):
	var err = client.connect_to_host(ip, port)
	if err != OK:
		print("Failed to connect:", err)

func _process(_delta):
	client.poll()
	if not connected and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connected = true
		print("Connected to Python!")

	if connected and client.get_available_bytes() > 0:
		var data = client.get_data(client.get_available_bytes())
		if data[0] == OK:
			buffer += data[1]

		while true:
			var newline_index = buffer.find(10)
			if newline_index == -1:
				break
			var line = buffer.slice(0, newline_index).get_string_from_utf8()
			buffer = buffer.slice(newline_index + 1, buffer.size())
			emit_signal("move_received", line)
