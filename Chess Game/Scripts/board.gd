extends Node2D

@export var board_center = Vector2(576, 320)
var board_origin: Vector2

const piece_scene = preload("res://piece.tscn")
const BOARD_SIZE = 8
const TILE_SIZE = 64

const FEN_MAP = {
	"p": "bp", "n": "bn", "b": "bb", "r": "br", "q": "bq", "k": "bk",
	"P": "wp", "N": "wn", "B": "wb", "R": "wr", "Q": "wq", "K": "wk",
}

var pieces = []
var current_turn = "white"

func _on_piece_moved(from: Vector2i, to: Vector2i, piece: Node2D):
	clear_piece_at(from.x, from.y)
	set_piece_at(to.x, to.y, piece)

func _on_piece_dragged(uci: String):
	print("Drag move received:", uci)
	_on_connection_manager_move_received(current_turn + ":" + uci + "\n")
	apply_move(uci, true)  # Apply move forcibly


func get_uci_from_coords(from: Vector2i, to: Vector2i) -> String:
	var col_to_file = ["a", "b", "c", "d", "e", "f", "g", "h"]
	var from_file = col_to_file[from.x]
	var from_rank = str(8 - from.y)
	var to_file = col_to_file[to.x]
	var to_rank = str(8 - to.y)
	return from_file + from_rank + to_file + to_rank

func set_board(fen: String):
	# Remove existing pieces
	for child in get_children():
		if child is Node2D and child.name.begins_with("Piece"):
			child.queue_free()
	# Fill the board from the FEN string
	var rows = fen.split("/")
	# Ensure the FEN string is the correct length
	if rows.size() != BOARD_SIZE:
		push_error("Invalid FEN: must have 8 ranks")
		return
	for row_idx in range(BOARD_SIZE):
		var col = 0
		for c in rows[row_idx]:
			if c.is_valid_int():
				col += int(c)
			elif c in FEN_MAP:
				var piece_type = FEN_MAP[c]
				var piece = piece_scene.instantiate()
				piece.piece_type = piece_type
				piece.is_white = piece_type[0] == "w"
				piece.name = "Piece_%s_%d_%d" % [piece_type, row_idx, col]
				piece.position = Vector2(col, row_idx) * TILE_SIZE + board_origin
				piece.piece_moved.connect(_on_piece_moved)
				piece.piece_dragged.connect(_on_piece_dragged)
				add_child(piece)
				set_piece_at(col, row_idx, piece)
				col += 1

func reset_board(fen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"):
	# Ensure FEN is valid
	if not $ChessRuleManager.is_valid_fen(fen):
		push_error("FEN validation failed. Board not reset.")
		return
	
	# Split the FEN into sections
	var parts = fen.strip_edges().split(" ")
	var board_fen = parts[0]
	var castling_fen = parts[2] if parts.size() > 2 else "-"
	
	# Update castling rights at the start
	$ChessRuleManager.set_castling_rights_from_fen(castling_fen)
	
	# Clear the board
	for row in pieces:
		for piece in row:
			if piece:
				piece.queue_free()
				
	# Recreate an empty board
	pieces = []
	for _i in range(BOARD_SIZE):
		pieces.append([])
		for _j in range(BOARD_SIZE):
			pieces[_i].append(null)
	
	# Populate the pieces
	set_board(board_fen)

func snap_to_grid(world_pos: Vector2, origin: Vector2 = board_origin) -> Vector2:
	# Snap the piece's position to the nearest grid position
	var local_pos = world_pos - origin
	var col = clamp(round(local_pos.x / TILE_SIZE), 0, BOARD_SIZE-1)
	var row = clamp(round(local_pos.y / TILE_SIZE), 0, BOARD_SIZE-1)
	return origin + Vector2(col, row) * TILE_SIZE

func world_pos_to_board_idx(pos: Vector2) -> Variant:
	var local = pos - board_origin
	var col = int(round(local.x / TILE_SIZE))
	var row = int(round(local.y / TILE_SIZE))
	# Check board bounds
	if col < 0 or col > BOARD_SIZE-1 or row < 0 or row > BOARD_SIZE-1:
		return null
	return Vector2i(col, row)

func board_idx_to_pos(idx: Vector2i) -> Vector2:
	return board_origin + Vector2(idx.x, idx.y) * TILE_SIZE

func get_piece_at(col: int, row: int) -> Node2D:
	if col < 0 or col >= BOARD_SIZE or row < 0 or row >= BOARD_SIZE:
		return null
	return pieces[row][col]

func set_piece_at(col: int, row: int, piece: Node2D):
	pieces[row][col] = piece

func clear_piece_at(col: int, row: int):
	pieces[row][col] = null

func get_fen() -> String:
	var reverse_fen_map = {}
	for key in FEN_MAP.keys():
		reverse_fen_map[FEN_MAP[key]] = key

	var rows = []

	for row_idx in range(BOARD_SIZE):
		var row_fen = ""
		var empty_count = 0

		for col in range(BOARD_SIZE):
			var piece = get_piece_at(col, row_idx)
			if piece == null:
				empty_count += 1
			else:
				if empty_count > 0:
					row_fen += str(empty_count)
					empty_count = 0
				var piece_key = piece.piece_type
				if reverse_fen_map.has(piece_key):
					row_fen += reverse_fen_map[piece_key]
				else:
					push_warning("Unknown piece type: " + piece_key)

		if empty_count > 0:
			row_fen += str(empty_count)

		rows.append(row_fen)

	var piece_placement = "/".join(rows)
	var active_color = "w" if current_turn == "white" else "b"
	var castling_rights = $ChessRuleManager.get_castling_rights()
	var en_passant = "-"  # You can implement this later
	var halfmove_clock = "0"  # Placeholder
	var fullmove_number = "1"  # Placeholder

	return "%s %s %s %s %s %s" % [
		piece_placement, active_color, castling_rights, en_passant, halfmove_clock, fullmove_number
]

func apply_move(uci: String, force_move: bool = false) -> bool:
	# Apply a move from a UCI string like "e4e5"
	if uci.length() < 4:
		push_warning("Invalid UCI Length: " + uci)
		return false
	
	# Convert UCI to coordinates
	var file_to_col = {"a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7}
	var from_coords = Vector2i(file_to_col[uci[0]], 8 - int(uci[1]))
	var to_coords = Vector2i(file_to_col[uci[2]], 8 - int(uci[3]))
	
	# Get the moving piece
	var piece = get_piece_at(from_coords.x, from_coords.y)
	if piece == null:
		# Cannot move from location without a piece
		push_warning("No piece at " + str(from_coords))
		return false
		
	if not force_move:
		if not piece.is_white and current_turn == "white" or piece.is_white and current_turn == "black":
			# Cannot move opponent's piece
			return false
		if not $ChessRuleManager.is_valid_move(uci):
			# Invalid move
			return false
		
	var color = "w" if piece.is_white else "b"

	# Promotion handling
	if uci.length() == 5 and piece.piece_type.ends_with("p"):
		var promotion_piece := uci[4].to_lower()
		var promotion_rank = 0 if piece.is_white else 7
		if to_coords.y == promotion_rank:
			if promotion_piece in ["q", "r", "b", "n"]:
				piece.change_piece_type(color + promotion_piece)
			else:
				push_warning("Invalid promotion piece: " + promotion_piece)
		else:
			push_warning("Promotion not allowed to rank " + str(to_coords.y))
	
	# Detect and handle castling
	if piece.piece_type.ends_with("k") and abs(from_coords.x - to_coords.x) == 2:
		var rook_from: Vector2i
		var rook_to: Vector2i
		if to_coords.x == 6: # Kingside
			rook_from = Vector2i(7, from_coords.y)
			rook_to = Vector2i(5, from_coords.y)
		elif to_coords.x == 2: # Queenside
			rook_from = Vector2i(0, from_coords.y)
			rook_to = Vector2i(3, from_coords.y)

		var rook = get_piece_at(rook_from.x, rook_from.y)
		if rook:
			clear_piece_at(rook_from.x, rook_from.y)
			set_piece_at(rook_to.x, rook_to.y, rook)
			rook.move_piece_to(rook_from, rook_to, true)
	
	# Update castling rights
	$ChessRuleManager.update_castling_rights(uci)
	
	# Apply the move (with animation)
	piece.move_piece_to(from_coords, to_coords, true)
	
	# Update the current turn
	current_turn = "black" if current_turn == "white" else "white"
	return true

func _on_connection_manager_move_received(message: String, force: bool=false) -> void:
	var parts = message.split(":")
	if parts.size() < 2:
		print("Malformed message: ", message)
		return
	var role = parts[0]
	var uci = parts[1]
	
	print(role, " sent: ", uci)

	if not force and role != current_turn:
		print("Move rejected: not ", role, "'s turn.")
		$ConnectionManager.send_message("OUTOFTURN:" + role)
		return
	var success = apply_move(uci)
	if not success:
		print("Move rejected: Invalid")
		$ConnectionManager.send_message("INVALID:" + uci + ":" + role)
		# Make the bot try again
		$ConnectionManager.send_message("TURN:" + self.current_turn)
		return
	print("Updated FEN: ", get_fen())
	$ConnectionManager.send_message("FEN:" + get_fen())
	$ConnectionManager.send_message("TURN:" + self.current_turn)

func _ready():
	board_origin = board_center - Vector2(BOARD_SIZE/2-0.5, BOARD_SIZE/2-0.5) * TILE_SIZE
	reset_board()
	var bot_game = true
	
	if bot_game:
		# Connect to the bot server
		$ConnectionManager.connect_to_bot()
		await get_tree().create_timer(3.0).timeout
		# Start the game
		$ConnectionManager.send_message("FEN:" + get_fen())
		$ConnectionManager.send_message("TURN:white")
	
	else:
		await get_tree().create_timer(2.0).timeout
		# Play a test game
		var moves = [
'd2d4', 'd7d5', 'c2c4', 'c8d7', 'g1f3', 'c7c6', 'e2e3', 'd8c8', 'f1d3', 'd5c4', 'e1e2', 'g7g6', 'd3c4', 'f7f6', 'h1e1', 'f8g7', 'e2f1', 'g8h6', 'f1g1', 'h8g8', 'b1d2', 'g8h8', 'e3e4', 'e8d8', 'd1b3', 'b7b6', 'e4e5', 'd8c7', 'd4d5', 'c7b7', 'd5c6', 'b8c6', 'c4d5', 'f6e5', 'd5c6', 'd7c6', 'd2e4', 'h6f5', 'c1g5', 'f5d4', 'b3c4', 'e7e6', 'c4e6', 'c6e4', 'e6c4', 'c8c4', 'a1c1', 'c4d3', 'e1d1', 'd3a6', 'g5e7', 'h8e8', 'e7d6', 'd4f3', 'g2f3', 'a8c8', 'c1c7', 'c8c7', 'd6c7', 'b7c7', 'f3e4', 'e8d8', 'd1f1', 'd8d2', 'g1g2', 'a6e2', 'g2g3', 'd2d3', 'g3g2', 'e2g4', 'g2h1', 'g4h3', 'h1g1', 'g7h6', 'g1h1', 'h6f4', 'h1g1', 'h3h2'
]
		for move in moves:
			apply_move(move)
			await get_tree().create_timer(0.3).timeout
		print("Done!")
