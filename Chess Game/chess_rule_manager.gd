extends Node

@onready var board = get_parent()

# Castling rights
var w_can_castle_q = true
var w_can_castle_k = true
var b_can_castle_q = true
var b_can_castle_k = true

const FEN_MAP = {
	"p": "bp", "n": "bn", "b": "bb", "r": "br", "q": "bq", "k": "bk",
	"P": "wp", "N": "wn", "B": "wb", "R": "wr", "Q": "wq", "K": "wk",
}

func get_castling_rights() -> String:
	var rights = ""
	if w_can_castle_k:
		rights += "K"
	if w_can_castle_q:
		rights += "Q"
	if b_can_castle_k:
		rights += "k"
	if b_can_castle_q:
		rights += "q"
	if rights == "":
		rights = "-"
	return rights

func update_castling_rights(uci: String):
	# Revoke castling rights based on moves
	if uci.begins_with("e1"):
		w_can_castle_k = false
		w_can_castle_q = false
	elif uci.begins_with("e8"):
		b_can_castle_k = false
		b_can_castle_q = false
	elif uci.begins_with("h1"):
		w_can_castle_k = false
	elif uci.begins_with("a1"):
		w_can_castle_q = false
	elif uci.begins_with("h8"):
		b_can_castle_k = false
	elif uci.begins_with("a8"):
		b_can_castle_q = false

	# Each player can only castle once
	match uci:
		"e1g1", "e1c1":
			w_can_castle_k = false
			w_can_castle_q = false
		"e8g8", "e8c8":
			b_can_castle_k = false
			b_can_castle_q = false

func set_castling_rights_from_fen(fen: String):
	# Update rights based on FEN string
	w_can_castle_k = "K" in fen
	w_can_castle_q = "Q" in fen
	b_can_castle_k = "k" in fen
	b_can_castle_q = "q" in fen

func is_valid_move(uci: String) -> bool:
	# Convert UCI to coordinates
	var file_to_col = {"a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7}
	var from = Vector2i(file_to_col[uci[0]], 8 - int(uci[1]))
	var to = Vector2i(file_to_col[uci[2]], 8 - int(uci[3]))
	
	if from == to:
		# UCI must denote an actual move
		return false
	# Get moving piece (and target piece, if any)
	var piece = board.get_piece_at(from.x, from.y)
	var target_piece = board.get_piece_at(to.x, to.y)
	if piece == null:
		return false
	# Cannot capture same-color piece
	if target_piece != null and target_piece.is_white == piece.is_white:
		return false
	
	match piece.piece_type:
		"wp", "bp":
			return is_valid_pawn_move(from, to, uci)
		"wr", "br":
			return is_valid_rook_move(from, to)
		"wb", "bb":
			return is_valid_bishop_move(from, to)
		"wq", "bq":
			return is_valid_queen_move(from, to)
		"wn", "bn":
			return is_valid_knight_move(from, to)
		"wk", "bk":
			return is_valid_king_move(from, to)
	
	return false
	
func is_path_clear(from: Vector2i, to: Vector2i) -> bool:
	# Determine if there is a clear path from start to finish spaces
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)
	var pos = from + Vector2i(dx, dy)
	while pos != to:
		if board.get_piece_at(pos.x, pos.y) != null:
			return false
		pos += Vector2i(dx, dy)
	return true


func is_valid_pawn_move(from: Vector2i, to: Vector2i, uci: String):
	var dx = to.x - from.x
	var dy = to.y - from.y
	var piece = board.get_piece_at(from.x, from.y)
	var target_piece = board.get_piece_at(to.x, to.y)
	# Handling for "forward" direction (based on color)
	var moving_direction = -1 if piece.is_white else 1
	var start_rank = 6 if piece.is_white else 1
	var final_rank = 0 if piece.is_white else 7
	
	# Handle promotion
	var is_promoting = to.y == final_rank
	var has_promo_suffix = uci.length() == 5
	var promo_piece = uci[4].to_lower() if has_promo_suffix else ""
	var valid_promo = promo_piece in ["q", "r", "b", "n"]
		
	if dx == 0:
		print(dy==moving_direction, ", ", has_promo_suffix)
		if dy == moving_direction and target_piece == null:
			# A normal move, advancing one square
			if is_promoting:
				# Ensure valid promotion
				return valid_promo
				
			# Don't allow moves with a promotion suffix if they aren't promoting
			return not has_promo_suffix
		if (
			dy == 2 * moving_direction and 
			from.y == start_rank and 
			target_piece == null and 
			board.get_piece_at(to.x, from.y + moving_direction) == null
		):
			# A move where the pawn advances 2 squares from its starting row
			return true
			
	elif abs(dx) == 1 and dy == moving_direction:
		# A capture where the pawn moves 1 space diagonally forward
		if target_piece != null and target_piece.is_white != piece.is_white:
			# Only capture opponent's pieces
			return true
	return false
	
	
func is_valid_rook_move(from: Vector2i, to: Vector2i):
	if from.x != to.x and from.y != to.y:
		# Diagonal move
		return false
	return is_path_clear(from, to)
	
func is_valid_bishop_move(from: Vector2i, to: Vector2i):
	# x and y should change by the same amount (diagonal)
	return abs(from.x - to.x) == abs(from.y - to.y)

func is_valid_queen_move(from: Vector2i, to: Vector2i):
	# The queen can move like a bishop or like a rook
	return is_valid_bishop_move(from, to) or is_valid_rook_move(from, to)
	
func is_valid_knight_move(from: Vector2i, to: Vector2i):
	var dx = abs(from.x - to.x)
	var dy = abs(from.y - to.y)
	# Knights must move two spaces in one axis, and one in the other
	return (dx == 1 and dy == 2) or (dx == 2 and dy == 1)
	
func is_valid_king_move(from: Vector2i, to: Vector2i):
	var dx = abs(from.x - to.x)
	var dy = abs(from.y - to.y)
	
	if dx <= 1 and dy <= 1:
		# Standard king move, one space in any direction
		return true
	
	# Handle castling on either side for both kings
	var rights = get_castling_rights()
	
	if from == Vector2i(4, 7):  # white king start square
		if dx == 2 and rights.find("K") != -1:  # kingside
			return is_path_clear(from, Vector2i(7, 7))
		elif dx == -2 and rights.find("Q") != -1:  # queenside
			return is_path_clear(from, Vector2i(0, 7))

	elif from == Vector2i(4, 0):  # black king start square
		if dx == 2 and rights.find("k") != -1:  # kingside
			return is_path_clear(from, Vector2i(7, 0))
		elif dx == -2 and rights.find("q") != -1:  # queenside
			return is_path_clear(from, Vector2i(0, 0))
	return false


func is_valid_fen(fen: String) -> bool:
	var parts = fen.strip_edges().split(" ")
	if parts.size() != 6:
		push_error("Invalid FEN: must have 6 space-separated fields")
		return false

	var board_part = parts[0]
	var active_color = parts[1]
	var castling = parts[2]
	var en_passant = parts[3]
	var halfmove = parts[4]
	var fullmove = parts[5]

	# Check board structure
	var rows = board_part.split("/")
	if rows.size() != 8:
		push_error("Invalid FEN: board must have 8 ranks")
		return false

	for row in rows:
		var count = 0
		for char in row:
			if char.is_valid_int():
				count += int(char)
			elif char in FEN_MAP.keys():
				count += 1
			else:
				push_error("Invalid FEN: unknown character in board layout: " + char)
				return false
		if count != 8:
			push_error("Invalid FEN: rank does not sum to 8")
			return false

	# Validate active color
	if active_color != "w" and active_color != "b":
		push_error("Invalid FEN: active color must be 'w' or 'b'")
		return false

	# Validate castling field
	var castling_regex = RegEx.new()
	castling_regex.compile("^[KQkq]+$")
	if castling != "-" and not castling_regex.search(castling):
		push_error("Invalid FEN: invalid castling rights field")
		return false

	# Validate en passant square (either '-' or a square like 'e3')
	var en_pass_regex = RegEx.new()
	en_pass_regex.compile("^[a-h][36]$")
	if en_passant != "-" and not en_pass_regex.search(en_passant):
		push_error("Invalid FEN: invalid en passant target square")
		return false

	# Validate halfmove/fullmove
	if not halfmove.is_valid_int() or not fullmove.is_valid_int():
		push_error("Invalid FEN: halfmove and fullmove must be integers")
		return false
	if int(fullmove) < 1:
		push_error("Invalid FEN: fullmove number must be at least 1")
		return false

	return true
