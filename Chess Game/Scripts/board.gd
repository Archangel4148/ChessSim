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
				add_child(piece)
				set_piece_at(col, row_idx, piece)
				col += 1

func reset_board(fen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"):
	for row in pieces:
		for piece in row:
			if piece:
				piece.queue_free()
				
	# Create the empty board state
	pieces = []
	for _i in range(BOARD_SIZE):
		pieces.append([])
		for _j in range(BOARD_SIZE):
			pieces[_i].append(null)
	# Populate the pieces
	set_board(fen)

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

	return "/".join(rows)

func apply_move(uci: String) -> bool:
	# Apply a move from a UCI string like "e4e5"
	if uci.length() < 4:
		push_warning("Invalid move: " + uci)
		return false
	# Parse coordinates from the string
	var file_to_col = {"a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7}
	var from_coords = Vector2i(file_to_col[uci[0]], 8 - int(uci[1]))
	var to_coords = Vector2i(file_to_col[uci[2]], 8 - int(uci[3]))
	# Get the moving piece
	var piece = get_piece_at(from_coords.x, from_coords.y)
	if not piece.is_white and current_turn == "white" or piece.is_white and current_turn == "black":
		# Cannot move other player's piece
		return false
	if piece == null:
		push_warning("No piece at " + str(from_coords))
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
	
	# Apply the move (with animation)
	piece.move_piece_to(from_coords, to_coords, true)
	return true

func _ready():
	board_origin = board_center - Vector2(BOARD_SIZE/2-0.5, BOARD_SIZE/2-0.5) * TILE_SIZE
	reset_board()
	var bot_game = true
	
	if bot_game:
		# Connect to the bot server
		$ConnectionManager.connect_to_bot()
	
	else:
		await get_tree().create_timer(2.0).timeout
		# Play a test game
		var moves = [
			'e2e4', 'e7e5', 'f2f4', 'e5f4', 'f1c4', 'd8h4', 'e1f1', 'b7b5', 'c4b5', 'g8f6', 'g1f3', 'h4h6', 'd2d3', 'f6h5', 'f3h4', 'h6g5', 'h4f5', 'c7c6', 'g2g4', 'h5f6', 'h1g1', 'c6b5', 'h2h4', 'g5g6', 'h4h5', 'g6g5', 'd1f3', 'f6g8', 'c1f4', 'g5f6', 'b1c3', 'f8c5', 'c3d5', 'f6b2', 'f4d6', 'c5g1', 'e4e5', 'b2a1', 'f1e2', 'b8a6', 'f5g7', 'e8d8', 'f3f6', 'g8f6', 'd6e7'
		]
		
		for move in moves:
			apply_move(move)
			await get_tree().create_timer(0.85).timeout
		print("Done!")
 


func _on_connection_manager_move_received(message: String) -> void:
	var parts = message.split(":")
	if parts.size() < 2:
		print("Malformed message:", message)
		return
	var role = parts[0]
	var uci = parts[1]
	
	print(role, " sent: ", uci)
	
	if role != current_turn:
		print("Move rejected: not ", role, "'s turn.")
		$ConnectionManager.send_message("OUTOFTURN:" + role)
		return

	var success = apply_move(uci)
	if not success:
		print("Move rejected: invalid UCI")
		$ConnectionManager.send_message("INVALID:" + uci + ":" + role)
		return

	# Turn was valid, swap turns
	current_turn = "black" if current_turn == "white" else"white"
