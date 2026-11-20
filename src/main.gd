extends Node

const PIE_CHART_SCALE := Vector2(0.9, 0.9)
const PIE_CHART_START_POSITION_Y: float = 260.0
const PIE_CHART_END_POSITION_Y: float = -40.0

@export var _map_node: Map

@onready var _ui := %UI as Control

@onready var _shadow := %Shadow as Panel
@onready var _pie_chart := %PieChart as PieChart
@onready var _title_label := %Title as RichTextLabel

@onready var _button_container := %ButtonContainer as VBoxContainer
@onready var _continue_button := %Continue as GameButton
@onready var _new_game_button := %NewGame as GameButton

@onready var _copyright_label := %Copyright as RichTextLabel
@onready var _version_label := %Version as RichTextLabel

func _ready() -> void:
	randomize()
	Global.enemy_deck.deck_creator(false)
	
	_title_label.modulate.a = 0.0
	_shadow.modulate.a = 0.0
	_button_container.modulate.a = 0.0
	_copyright_label.modulate.a = 0.0
	_version_label.modulate.a = 0.0
	_button_container.hide()
	
	var beta_text: String = ""
	if Global.IS_BETA:
		beta_text += "β "
	_version_label.text = beta_text + "ver.%s" % Global.version
	
	if SaveManager.is_new_data:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()
	
	_map_node.setup_for_title()
	
	if Global.player_deck and Global.player_deck.monster[0] and Global.player_deck.monster[0].data:
		var float_chances: Array[float]
		float_chances.assign(Global.player_deck.monster[0].chance)
		_pie_chart.actions = Global.action_to_actiondata(Global.player_deck.monster[0].data.action)
		_pie_chart.chances = float_chances
	else:
		# モンスターが存在しなかった場合、ダミーのモンスターを生成しそのデータを使用します
		var dummy_monster := Monster.new()
		dummy_monster.data = Global.monster_data[1]
		dummy_monster.random_action_selector()
		
		var float_chances: Array[float]
		float_chances.assign(dummy_monster.chance)
		_pie_chart.actions = Global.action_to_actiondata(dummy_monster.data.action)
		_pie_chart.chances = float_chances
	
	if SaveManager.is_new_data:
		_continue_button.disabled = true
	
	if Global.is_first_launch:
		Global.is_first_launch = false
		await SceneManager.fade_in_transparent(1.0)
	
	_show_title_animation()

## ゲームタイトルを表示するアニメーションを再生します
func _show_title_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_interval(0.5)
	tween.tween_property(_pie_chart, "position:y", PIE_CHART_END_POSITION_Y, 1.0).from(PIE_CHART_START_POSITION_Y)
	tween.parallel().tween_property(_pie_chart, "scale", PIE_CHART_SCALE, 1.0).from(Vector2.ZERO)
	
	tween.tween_property(_title_label, "modulate:a", 1.0, 1.0).from(0.0)
	tween.parallel().tween_property(_shadow, "modulate:a", 1.0, 1.0).from(0.0)
	await tween.finished
	
	_button_container.show()
	tween = create_tween().set_parallel()
	tween.tween_property(_button_container, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(_copyright_label, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(_version_label, "modulate:a", 1.0, 0.5).from(0.0)


func _hide_title_animation() -> void:
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_pie_chart, "position:y", PIE_CHART_START_POSITION_Y, 1.0).from(PIE_CHART_END_POSITION_Y)
	tween.tween_property(_pie_chart, "scale", Vector2.ZERO, 1.0).from(PIE_CHART_SCALE)
	
	tween.tween_property(_ui, "modulate:a", 0.0, 1.0).from(1.0)
	await tween.finished

func _on_continue_button_up() -> void:
	_change_to_map_scene()


func _on_new_game_button_up() -> void:
	if SaveManager.is_new_data:
		_change_to_map_scene()
	else:
		var selected_index: int = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/main/delete_save_data_1.tres"))
		if selected_index == 1:
			SaveManager.delete_game()
			
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/main/delete_save_data_2.tres"))
			DialogManager.hide_dialog()
			
			_change_to_map_scene()
		else:
			DialogManager.hide_dialog()


func _on_credit_button_up() -> void:
	await DialogManager.set_text_dialog(preload("res://resource/dialog_data/main/credit.tres"))
	DialogManager.hide_dialog()


func _change_to_map_scene() -> void:
	SceneManager.block_input()
	await _hide_title_animation()
	SceneManager.change_scene(Global.MAP_SCENE, SceneManager.no_fade_out, SceneManager.no_fade_in)
