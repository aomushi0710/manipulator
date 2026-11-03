class_name Dialog
extends CanvasLayer
## 汎用ダイアログシステム。[DialogData]を用いて様々なパターンのダイアログを表示します。

signal option_selected(i: int) ## ボタンが押された時にそのボタンのindexを発行します

const SCALE: Vector2 = Vector2.ONE ## ダイアログ表示時の[member Control.scale]
const ANIMATION_SPEED: float = 0.1 ## ダイアログ表示切替アニメーションにかかる秒数

#@onready var _screen_overlay := %ScreenOverlay as ColorRect ## ダイアログ外部に表示されるマスク
@onready var _panel_container := %PanelContainer as PanelContainer ## ダイアログ本体
@onready var _border := %Border as Panel ## タイトルと本文の間に表示される線
@onready var _title_label := %Title as RichTextLabel ## タイトル
@onready var _text_label := %Text as RichTextLabel ## 本文
@onready var _background := %Background as TextureRect ## 本文の背景に表示される画像
#@onready var _text_area := %TextArea as MarginContainer ## [member Dialog._text_label]と[member Dialog._background]を表示する領域
@onready var _button_container := %ButtonContainer as HBoxContainer ## ボタンを複数格納できるコンテナ

var _local_stylebox: StyleBoxFlat ## テーマ上書き用StyleBox
var _has_title: bool ## ダイアログタイトルの有無

func _ready() -> void:
	_local_stylebox = _panel_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_panel_container.add_theme_stylebox_override("panel", _local_stylebox)

## [DialogData]を引数としてダイアログを作成し表示します。
## [member DialogData.title]及び[member DialogData.text]中に{0}、{1}、{2}...のようにプレースホルダーを設定すると、[param format_args]配列の対応するindexにあるテキストを動的に読み込むことができます。
## [br]表示は自動で行われますが、非表示は[method Dialog.hide_dialog]で明示的に行う必要があります。
func set_dialog(data: DialogData, format_args: Array = []) -> int:
	var formatted_title: String = data.title ## [method String.format]を用いて動的に変更されたタイトルテキスト
	var formatted_text: String = data.text ## [method String.format]を用いて動的に変更された本文テキスト
	
	if not format_args.is_empty():
		formatted_title = formatted_title.format(format_args)
		formatted_text = formatted_text.format(format_args)
	_text_label.text = formatted_text
	
	# テキストに合わせてサイズを調整
	const MIN_WIDTH: float = 860.0
	const MAX_WIDTH: float = 1820.0
	const MAX_HEIGHT: float = 800.0
	var raw_text: String = _text_label.get_parsed_text()
	var font: Font = _text_label.get_theme_font("normal_font_size")
	var font_size: int = _text_label.get_theme_font_size("normal_font_size")
	var text_width: int = font.get_multiline_string_size(raw_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_panel_container.custom_minimum_size.x = maxf(_panel_container.custom_minimum_size.x, clampf(text_width, MIN_WIDTH, MAX_WIDTH) + 100)
	if _text_label.get_content_height() > MAX_HEIGHT:
		_text_label.custom_minimum_size.y = MAX_HEIGHT
		_text_label.scroll_active = true
	else:
		_text_label.custom_minimum_size.y = _text_label.get_content_height()
		_text_label.scroll_active = false
	
	# タイトルがなければ不要なノードを隠す
	if data.title.is_empty():
		_has_title = false
		_title_label.hide()
		_border.hide()
	else:
		_has_title = true
		_title_label.text = formatted_title
		_title_label.show()
		_border.show()
	
	_set_button(data, format_args)
	
	if data.background_texture:
		_background.texture = data.background_texture
		_background.show()
	else:
		_background.hide()
	
	if _local_stylebox:
		_local_stylebox.bg_color = data.dialog_color
		_local_stylebox.border_color = data.dialog_border_color
	# borderは色しか変更しないためself_modulateで対応
	_border.self_modulate = data.dialog_border_color
	
	if not visible:
		_show_dialog()
	
	var selected_index: int = (await option_selected) as int ## 押されたボタンのindex
	return selected_index

## ダイアログを非表示にします
func hide_dialog() -> void:
	_text_label.hide()
	_button_container.hide()
	if _has_title:
		_title_label.text = " " # コンテナの構造が崩れないように空白を入れておく
	
	var tween := _panel_container.create_tween()
	tween.tween_property(_panel_container, "scale:y", 0.1, ANIMATION_SPEED)
	tween.tween_property(_panel_container, "scale:x", 0, ANIMATION_SPEED)
	await tween.finished
	hide()
	
	for child in _button_container.get_children():
		(child as Button).hide()
	
	_panel_container.custom_minimum_size.x = 0

## ダイアログを表示します
func _show_dialog() -> void:
	var title: String = _title_label.text
	if _has_title:
		_title_label.text = " " # コンテナの構造が崩れないように空白を入れておく
	
	show()
	var tween := _panel_container.create_tween()
	tween.tween_property(_panel_container, "scale:x", SCALE.x, ANIMATION_SPEED)
	tween.tween_property(_panel_container, "scale:y", SCALE.y, ANIMATION_SPEED)
	await tween.finished
	
	#_title_label.show() # show_dialog関数内で個別設定するため不要
	_text_label.show()
	_button_container.show()
	
	if _has_title:
		_title_label.text = title

## [member DialogData.button_text]を基に必要に応じてボタンを生成し、表示・非表示を切り替えます
func _set_button(data: DialogData, format_args: Array) -> void:
	var current_button_count := _button_container.get_child_count()
	var required_button_count := data.button_text.size()
	for i in range(maxi(current_button_count, required_button_count)):
		var button: GameButton
		
		if i < required_button_count:
			if i < current_button_count:
				button = _button_container.get_child(i) as GameButton
			
			else:
				button = Global.GAME_BUTTON.instantiate() as GameButton
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.button_up.connect(option_selected.emit.bind(i))
				_button_container.add_child(button)
			
			var formatted_text: String = data.button_text[i]
			if not format_args.is_empty():
				formatted_text = formatted_text.format(format_args)
			button.text = formatted_text
			
			if data.button_color and i < data.button_color.size(): # ボタンの色指定があれば
				button.color = data.button_color[i]
			else:
				button.color = Color.YELLOW
			
			button.show()
		
		else:
			button = _button_container.get_child(i) as GameButton
			button.hide()
	
	var first_button = _button_container.get_child(0) as GameButton
	if first_button:
		first_button.grab_focus()
