class_name MapMenu
extends Control

signal toggled(is_open: bool)

const MENU_POSITION_X: float = -720.0
const TOGGLE_ANIMATION_SPEED: float = 0.2

var tween: Tween

@onready var _help_label := %ScrollingLabel as ScrollingLabel

func _ready() -> void:
	hide()
	_help_label.connect_hover_signal(self)


func open_menu() -> void:
	if tween and tween.is_running():
		return
	
	toggled.emit(true)
	
	_help_label.hide()
	show()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "position:x", 0.0, TOGGLE_ANIMATION_SPEED).from(MENU_POSITION_X)
	
	tween.tween_callback(_help_label.show)
	tween.tween_property(_help_label, "modulate:a", 1.0, TOGGLE_ANIMATION_SPEED).from(0.0)


func close_menu() -> void:
	if tween and tween.is_running():
		return
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_help_label, "modulate:a", 0.0, TOGGLE_ANIMATION_SPEED).from(1.0)
	
	tween.tween_property(self, "position:x", MENU_POSITION_X, TOGGLE_ANIMATION_SPEED).from(0.0)
	tween.tween_callback(hide)
	tween.tween_callback(toggled.emit.bind(false))
	
	await tween.finished


func _on_monster_button_up() -> void:
	SceneManager.change_scene(
		Global.SELECT_SCENE,
		SceneManager.fade_out_zoom,
		SceneManager.fade_in_transparent
	)


func _on_shop_button_up() -> void:
	SceneManager.change_scene(
		Global.SHOP_SCENE,
		SceneManager.fade_out_zoom,
		SceneManager.fade_in_transparent
	)


func _on_save_button_up() -> void:
	SaveManager.save_game()
	await DialogManager.set_text_dialog(preload("res://resource/dialog_data/common/save_complete.tres"))
	DialogManager.hide_dialog()


func _on_title_button_up() -> void:
	SaveManager.save_game()
	SceneManager.block_input()
	await close_menu()
	SceneManager.change_scene(Global.MAIN_SCENE, SceneManager.no_fade_out, SceneManager.no_fade_in)


func _on_close_button_up() -> void:
	close_menu()
