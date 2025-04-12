extends Node2D

@export var piece_type: String = "wp"
@onready var board = get_parent()

signal piece_moved(from: Vector2i, to: Vector2i, piece: Node2D)

var is_white: bool
var dragging = false
var original_pos: Vector2
var sprite_size

const PIECE_FRAME_INDEX = {
	"wp": 0, "wn": 1, "wb": 2, "wr": 3, "wq": 4, "wk": 5,
	"bp": 6, "bn": 7, "bb": 8, "br": 9, "bq": 10, "bk": 11,
}

func _input(event):
	if not is_inside_tree(): return
	var mouse_pos = get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_mouse_over(mouse_pos):
					dragging = true
					original_pos = global_position
					move_to_front()
			else:
				if dragging:
					dragging = false
					drop_piece(mouse_pos)
	
func _process(delta):
	if dragging:
		global_position = get_global_mouse_position()

func is_mouse_over(mouse_pos: Vector2) -> bool:
	var local_mouse_pos = to_local(mouse_pos)
	var rect = Rect2(-sprite_size / 2, sprite_size)
	return rect.has_point(local_mouse_pos)

func drop_piece(mouse_pos: Vector2):
	var from_idx = board.world_pos_to_board_idx(original_pos)
	var target_idx = board.world_pos_to_board_idx(mouse_pos)
	if target_idx == null:
		global_position = original_pos
		return
	move_piece_to(from_idx, target_idx)

func move_piece_to(from_idx: Vector2i, target_idx: Vector2i, animate: bool=false):	
	# If there is a piece on the space, capture it
	var occupying_piece = board.get_piece_at(target_idx.x, target_idx.y)
	if occupying_piece and occupying_piece != self:
		occupying_piece.queue_free()

	# Move the piece visually
	var target_position = board.board_idx_to_pos(target_idx)
	
	if animate:
		# Smooth movement
		var tween = create_tween()
		tween.tween_property(self, "global_position", target_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	else:
		# Instant move
		global_position = target_position
		
	# Trigger the board state update
	piece_moved.emit(from_idx, target_idx, self)

func change_piece_type(new_type: String):
	# Update the piece type
	piece_type = new_type
	var sprite = $AnimatedSprite2D
	if piece_type in PIECE_FRAME_INDEX:
		sprite.frame = PIECE_FRAME_INDEX[piece_type]
	# Cache hitbox size
	var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	sprite_size = tex.get_size() * sprite.scale

func _ready():
	change_piece_type(piece_type)
