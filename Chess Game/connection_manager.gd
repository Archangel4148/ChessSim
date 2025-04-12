extends Node

signal move_received(message: String)

var client := StreamPeerTCP.new()
var connected := false
var buffer := PackedByteArray()

func connect_to_bot(ip: String = "127.0.0.1", port: int = 65432, role: String = "viewer"):
	var err = client.connect_to_host(ip, port)
	if err != OK:
		print("Failed to connect:", err)
	else:
		# Polling will start and connection state will be checked in _process
		print("Connecting to Python server as role:", role)
		await get_tree().create_timer(0.2).timeout  # slight delay to ensure connection setup
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			connected = true
			print("Connected to Python!")
			_send_role(role)

func send_message(msg: String):
	if connected:
		client.put_data((msg + "\n").to_utf8_buffer())

func _send_role(role: String):
	# Append newline for proper line delimiting
	var message = role.strip_edges() + "\n"
	client.put_data(message.to_utf8_buffer())

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
			var message = buffer.slice(0, newline_index).get_string_from_utf8()
			buffer = buffer.slice(newline_index + 1, buffer.size())
			emit_signal("move_received", message)
