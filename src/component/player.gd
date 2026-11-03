class_name Player
extends CharacterBody2D

const MOVE_SPEED: int = 384

@export var _dialog: MapDialog
@export var _terrain: TileMapLayer

var object_interactable: SignBoard ## 触れられるオブジェクトの参照
var _is_moving: bool = false ## 移動中かどうか
var can_move: bool = true: ## プレイヤーが移動可能かどうか
	set(value):
		can_move = value
		if not can_move:
			velocity = Vector2.ZERO
		
var _is_dialog_active: bool = false ## ダイアログが開かれているかどうか
var _dialog_just_closed: bool = false ## ダイアログが閉じられるまで入力を止めるかどうか
var is_input_enabled: bool = true: ## プレイヤーの入力を受け取って操作できるかどうか[br][member can_move]と異なり、移動以外の入力も受け付けません
	set(value):
		is_input_enabled = value
		if not is_input_enabled:
			velocity = Vector2.ZERO
		
		_collision_shape.disabled = not is_input_enabled

@onready var _sprite := %Sprite2D as Sprite2D
@onready var _collision_shape := %CollisionShape2D as CollisionShape2D
@onready var _interaction_area := %InteractionArea as Area2D ## プレイヤーの前方にある検知エリア

func _ready() -> void:
	if Global.player_deck and Global.player_deck.monster[0] and Global.player_deck.monster[0].data:
		_sprite.texture = Global.player_deck.monster[0].data.evolution_forms[Monster.Form.第一形態].image
	else:
		_sprite.texture = Global.monster_data[1].evolution_forms[Monster.Form.第一形態].image
	
	if SaveManager.save_data:
		position = SaveManager.save_data.map_position


func _physics_process(_delta: float) -> void:
	if not can_move or not is_input_enabled:
		return
	
	var direction: Vector2 = Vector2.ZERO ## 方向ベクトル
	var horizontal_input: int = Input.get_axis("left", "right")
	if horizontal_input != 0:
		direction.x = horizontal_input
	else:
		direction.y = Input.get_axis("up", "down")
	velocity = direction * MOVE_SPEED
	move_and_slide()
	
	var is_current_moving: bool ## 前フレームの状態を表す[member _is_moving]に対して、このフラグは現在のフレームの状態を表す
	if direction == Vector2.ZERO:
		is_current_moving = false
	else:
		is_current_moving = true
	
	if is_current_moving:
		_is_moving = true
		_interaction_area.position = direction * _terrain.tile_set.tile_size.x
	# 前フレームは動いていたが現在のフレームで止まった時、座標をセーブデータに記録する(セーブは行われない)
	elif _is_moving:
		_is_moving = false
		SaveManager.save_data.map_position = position


func _unhandled_input(event: InputEvent) -> void:
	if not is_input_enabled:
		return
	
	if event.is_action_released("interact"):
		var areas := _interaction_area.get_overlapping_areas()
		if not areas.is_empty():
			var signboard := areas[0]
			
			# 看板の処理
			if signboard is SignBoard:
				# INFO ダイアログを閉じると同時に開く判定になってしまうので、フラグを利用して処理を無理やり止めている
				if _dialog_just_closed: 
					_dialog_just_closed = false
					_is_dialog_active = false
					return
					
				# 既にダイアログが開かれているか、メニューが開かれていて動けないなら何もしない
				if _is_dialog_active or not can_move:
					return
				
				await _dialog.dialog_manager(signboard.dialog_datas, signboard.id)

## ダイアログが開かれた時、各種フラグを立てる関数
func _on_dialog_dialog_opened() -> void:
	can_move = false
	_is_dialog_active = true

## ダイアログが閉じられた時、各種フラグを立てる関数
func _on_dialog_dialog_closed() -> void:
	can_move = true
	_dialog_just_closed = true


func _on_menu_toggled(is_open: bool) -> void:
	can_move = not is_open
