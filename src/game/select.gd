class_name MenuMonster
extends Control

## [enum MenuMonster.Mode]が[param STATUS]の時、決定ボタン
##[member MenuMonster.confirm_button]が押されると発行される。
## [member MenuMonster.monster_setting]の最新のselected_monsterを取得する。
signal status_mode_confirm_button_up

enum Mode {
	DECK, ## デッキ編成画面
	MONSTER_SELECT, ## モンスター選択画面
	STATUS, ## 技セレクト画面(中央のステータス一括表示画面)
	ACTION, ## 技セレクト画面(右側の技出現確率設定画面)
}

## [enum Mode]に対応する[Control]ノードの[NodePath]の辞書
const MODE_TO_NODEPATH: Dictionary[Mode, String] = {
	Mode.DECK: "DeckMenu", 
	Mode.MONSTER_SELECT: "MonsterSelect", 
	Mode.STATUS: "MonsterSetting", 
	Mode.ACTION: "MonsterSetting", 
}

## [enum Mode]に対応する[param confirm_button]ノードの
##メタデータ[code]help_text[/code]に入る[String]の辞書
const CONFIRM_BUTTON_HELP_TEXT: Dictionary[Mode, String] = {
	Mode.DECK: " ", 
	Mode.MONSTER_SELECT: " ", 
	Mode.STATUS: "設定を保存し、パーティ編成画面へ戻ります。", 
	Mode.ACTION: "現在選択中の技を登録します。", 
}

## [enum Mode]に対応する[param back_button]ノードの
##メタデータ[code]help_text[/code]に入る[String]の辞書
const BACK_BUTTON_HELP_TEXT: Dictionary[Mode, String] = {
	Mode.DECK: "現在のデッキ内容を保存し、マップ画面へ戻ります。", 
	Mode.MONSTER_SELECT: "パーティ編成画面へ戻ります。", 
	Mode.STATUS: "[color=red]設定を保存せずに、[/color]モンスターセレクト画面へ戻ります。", 
	Mode.ACTION: "元の画面へ戻ります。", 
}

@export_category("CanvasLayer")
@export var se_menu: MenuSoundEmitter
@export var background: Control
@export var camera: Camera2D
@export var canvas_layer_ui: Control
@export var confirm_button: Button
@export var back_button: Button
@export var help_label: ScrollingLabel
@export var status_bar: Control
@export var evolution_preview: Control
@export var evolution_preview_button: OptionButton
@export var level_spinbox: SpinBox

var camera_tween: Tween
var selected_slot_index: int ## デッキ内で現在編集中のモンスターの位置を示すindex

## 現在選択中の[Monster]の複製。[br]
## デッキにいるモンスターに影響を与えずに各種データのプレビューを可能にするために使用。
var selected_monster: Monster:
	set(value):
		if value == null:
			return
		selected_monster = value.duplicate(true)
		monster_setting.selected_monster = selected_monster

## デッキ編成で現在表示中のモンスターの形態。[br]
## 値を変更すると自動で[code]update()[/code]関数を呼び、デッキ編成の見た目を変更します。
var preview_form: Monster.Form:
	set(form):
		preview_form = form
		evolution_preview_button.selected = preview_form
		match mode:
			Mode.DECK:
				deck_menu.update(preview_form)
			
			Mode.MONSTER_SELECT:
				monster_select.update(preview_form)
			
			Mode.STATUS, Mode.ACTION:
				monster_setting.selected_monster.form = preview_form

var level: int: ## プレビュー時のモンスターレベル
	set(value):
		level = value
		# 全ての形態のステータスを更新してリストに登録
		monster_setting.all_status_list.clear()
		for i in len(selected_monster.data.evolution_forms):
			monster_setting.all_status_list.append(selected_monster.data.evolution_forms[i].status_calculator(level))
		
		if mode == Mode.STATUS:
			monster_setting.monster_preview()
		elif mode == Mode.ACTION:
			monster_setting.monster_preview(true)



## 現在表示中の画面[br]
## この変数に代入を行う時は常に親ノードでの
var mode: Mode = Mode.DECK:
	set(next_mode): ## 対応する画面遷移を行ってからモード変更
		if not is_node_ready():
			return
		if not is_inside_tree():
			return
		
		# 全てのボタンを使用不可に
		for child in canvas_layer_ui.get_children():
			if child is Button:
				child.disabled = true
		
		for child in get_children():
			if child.name == MODE_TO_NODEPATH[next_mode]:
				child.show()
			else:
				child.hide()
		
		if evolution_preview.visible == false:
			evolution_preview.show()
		
		match next_mode:
			Mode.DECK:
				confirm_button.hide()
				status_bar.hide()
				deck_menu.on_mode_entered()
			
			Mode.MONSTER_SELECT:
				confirm_button.show()
				status_bar.hide()
				monster_select.on_mode_entered()
			
			Mode.STATUS:
				confirm_button.show()
				status_bar.show()
				
				# ACTIONとSTATUSからの遷移時は呼ばない
				if mode != Mode.ACTION and mode != Mode.STATUS:
					monster_setting.on_mode_entered()
				
				# 棒グラフの棒とボタンを表示するアニメーション
				status_bar.get_child(1).show()
				for container in status_bar.get_child(0).get_children():
					for child in container.get_children():
						if child is TextureRect:
							child.show()
				monster_setting.bar_chart_update()
				
				background.color_change(Color.GREEN) # 背景カラーチェンジ
				# カメラ移動アニメーション
				camera_tween = get_tree().create_tween().bind_node(camera)
				camera_tween.tween_property(camera, "offset:x", 960, 1)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
				confirm_button.text = "決定"
				
				await camera_tween.finished
			
			Mode.ACTION:
				confirm_button.show()
				status_bar.show()
				
				# 棒グラフの棒とボタンを隠すアニメーション
				status_bar.get_child(1).hide()
				for container in status_bar.get_child(0).get_children():
					for child in container.get_children():
						if child is TextureRect:
							monster_setting.bar_chart_animation(
									child, 
									0, 
									func(): child.hide()
							)
				
				evolution_preview.hide()
				
				background.color_change(Color.ORANGE) # 背景カラーチェンジ
				# カメラ移動アニメーション
				camera_tween = get_tree().create_tween().bind_node(camera)
				camera_tween.tween_property(camera, "offset:x", 1750, 1)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
				confirm_button.text = "登録"
				
				await camera_tween.finished
		
		# キャンバスレイヤーのヘルプテキスト再設定
		confirm_button.set_meta("help_text", CONFIRM_BUTTON_HELP_TEXT[next_mode])
		back_button.set_meta("help_text", BACK_BUTTON_HELP_TEXT[next_mode])
		help_label.connect_hover_signal(confirm_button)
		help_label.connect_hover_signal(back_button)
		
		# モード切り替え
		mode = next_mode
		# 全てのボタンを使用可能に
		for child in canvas_layer_ui.get_children():
			if child is Button:
				child.disabled = false
		if mode == Mode.ACTION and monster_setting.selected_action in monster_setting.actions: # 既に選ばれた技を選んだ時
			confirm_button.disabled = true # 再登録を不可に上書き

@onready var deck_menu := %DeckMenu as Control
@onready var monster_select := %MonsterSelect as Control
@onready var monster_setting := %MonsterSetting as Control

func _ready() -> void:
	mode = Mode.DECK
	help_label.connect_hover_signal($"..")

## 戻るボタンの処理
func _on_back_button_up():
	se_menu.click.play()
	match mode:
		Mode.DECK:
			if Global.player_deck.has_empty_slot():
				await DialogManager.set_text_dialog(preload("res://resource/dialog_data/select/deck_empty_slot.tres"))
				DialogManager.hide_dialog()
				return
			
			SaveManager.save_deck(0)
			
			SceneManager.change_scene(
				Global.MAP_SCENE,
				SceneManager.fade_out_transparent,
				SceneManager.fade_in_zoom
			)
		
		Mode.MONSTER_SELECT:
			mode = Mode.DECK
		
		Mode.STATUS: # キャラ選択に戻す
			var selected_index: int = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/select/go_back_without_save.tres"))
			if selected_index == 0:
				mode = Mode.MONSTER_SELECT
			DialogManager.hide_dialog()
		
		Mode.ACTION: # 画面を戻す
			mode = Mode.STATUS

## 決定ボタンの処理
func _on_confirm_button_up():
	se_menu.click.play()
	match mode:
		Mode.STATUS:
			status_mode_confirm_button_up.emit()
			
			var sum_chance = 0 ## 技の出現率の合計
			for i: int in monster_setting.chances:
				sum_chance += i
			if sum_chance != 100:
				await DialogManager.set_text_dialog(preload("res://resource/dialog_data/select/not_100_chance.tres"))
				DialogManager.hide_dialog()
				return
			
			Global.player_deck.monster[selected_slot_index] = selected_monster
			Global.player_deck.monster[selected_slot_index].chance = monster_setting.chances.duplicate()
			
			mode = Mode.DECK
		
		# TODO 押される場面がないため不要？
		Mode.ACTION:
			# 既存の技を選択中の時
			if monster_setting.selected_action in monster_setting.actions:
				Global.accept_dialog.display_dialog(
						"既に登録されている技です！\n\n" + 
						"───妙だな、\"今\"このボタンが押されるなんて。\n" + 
						"こんなこともあろうかと、対策を施していて正解だった。"
				)
				return
			if null not in monster_setting.actions: # 空きスペース(null)がない時
				Global.accept_dialog.display_dialog(
						"技は4個までしか登録できません！\n" + 
						"既に登録されている技を削除してください！"
				)
				return
			# 元々選択されている技の出現率に、登録したい技の出現率を足す計算
			var sum_chance = 0
			for i: int in monster_setting.chances:
				sum_chance += i
			if monster_setting.sum_chance + monster_setting.slider.value > 100:
				Global.accept_dialog.display_dialog(
						"技の出現率の合計が100%を越えてしまいます！")
				return
			
			confirm_button.disabled = true
			
			var index = monster_setting.actions.find(null) ## 空き枠のうち先頭のインデックスを取得
			monster_setting.actions[index] = monster_setting.selected_action
			monster_setting.chances[index] = int(monster_setting.slider.value)
			monster_setting.pie_chart_update()

## 進化プレビューオプションボタンで形態が選択された時の処理
func _on_option_button_item_selected(index: int) -> void:
	preview_form = index
	match mode:
		Mode.STATUS:
			monster_setting.monster_preview()
		
		Mode.ACTION:
			monster_setting.monster_preview(true)

## レベル設定のspinbox[param level_spinbox]の[member Range.value]が変更された時、
##[param level]の値を更新する
func _on_level_value_changed(value: float) -> void:
	level = value


func _on_selected_monster_changed(monster: Monster) -> void:
	selected_monster = monster


func _on_selected_slot_index_changed(index: int) -> void:
	selected_slot_index = index


func _on_get_selected_slot_index() -> void:
	monster_select._selected_slot_index = selected_slot_index
