extends Control

## 親の[member MenuMonster.selected_monster]変数に代入させるシグナル。[br]
## 返り値とするリソース[Monster]は親のsetterで複製されて渡される。
signal selected_monster_changed(monster: Monster)
signal evolution_form_changed(form: Monster.Form)
signal selected_slot_index_changed(index: int)

const DECK_SIZE: int = 3 ## デッキのサイズ

@export var parent: MenuMonster
@export var evolution_preview_button: OptionButton

@onready var deck_name_line_edit := %DeckName as LineEdit
@onready var monster_icon_container := %MonsterIconContainer as  HBoxContainer
@onready var monster_name_container := %MonsterNameContainer as  HBoxContainer

var max_evolution_form: Monster.Form ## デッキのモンスターで最大の進化形態
## 親の[member MenuMonster.selected_monster]を取得した結果が入る変数
var selected_monster: Monster


func on_mode_entered() -> void:
	evolution_form_changed.emit(Monster.Form.第一形態)
	# modeが違った時に、update関数がすり抜けないように
	if parent.mode != parent.Mode.DECK:
		update(Monster.Form.第一形態)


func update(form: Monster.Form) -> void:
	if Global.player_deck == null:
		return
	
	deck_name_line_edit.text = Global.player_deck.name
	for i in range(DECK_SIZE):
		## [Monster]型で、モンスターが存在するかの確認とレベルの取得に用いる
		var monster = Global.player_deck.monster[i]
		
		if monster.data == null:
			monster_icon_container.get_child(i).data = null
			monster_name_container.get_child(i).text = " \n "
		else:
			# formの形態を持たないモンスターはモンスターの持つ最後の形態で表示される
			if monster.data.evolution_forms.size() > form:
				monster.form = form
			else:
				monster.form = len(monster.data.evolution_forms) - 1
			
			monster_icon_container.get_child(i).data = monster.data
			monster_icon_container.get_child(i).form = monster.form
			monster_name_container.get_child(i).text = "[i]Lv.%2d[/i]\n[b]%s[/b]" % \
			[monster.level, monster.get_monsterform().name]
		
			if monster.data.evolution_forms.size() - 1 > max_evolution_form:
				max_evolution_form = monster.data.evolution_forms.size() - 1
	
	# 全てのモンスターがnullの時
	if Global.player_deck.monster.all(func(mon: Monster): return mon.data == null):
		# ALERT [param preview_form]に代入するとsetterによって再びこの関数が呼ばれる
		# ので、無限ループを防止すること
		if form != Monster.Form.第一形態:
			evolution_form_changed.emit(Monster.Form.第一形態)
		
		evolution_preview_button.disabled = true
	else:
		# 足りない形態の分だけ選択肢を追加する
		for i in range(max_evolution_form + 1):
			if evolution_preview_button.get_selectable_item(true) < i:
				evolution_preview_button.add_item(Monster.form_names[i], i)
		
		evolution_preview_button.disabled = false
	
	## 余分な選択肢を削除する回数
	var delete_count: int = (
		evolution_preview_button.get_item_count() - max_evolution_form - 1)
	for i in max(0, delete_count):
		evolution_preview_button.remove_item(
			evolution_preview_button.get_selectable_item(true))


func _on_save_button_up() -> void:
	SaveManager.is_save_mode = true
	SceneManager.change_scene(Global.DECK_SAVE_SCENE)


func _on_load_button_up() -> void:
	SaveManager.is_save_mode = false
	SceneManager.change_scene(Global.DECK_SAVE_SCENE)


func _on_auto_fill_button_up() -> void:
	Global.player_deck.deck_creator()
	evolution_form_changed.emit(Monster.Form.第一形態)


func _on_reset_button_up() -> void:
	var selected_index: int = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/deck_menu/reset_current_deck_1.tres"))
	if selected_index == 0:
		Global.player_deck = Deck.new()
		evolution_form_changed.emit(Monster.Form.第一形態)
		await DialogManager.set_text_dialog(preload("res://resource/dialog_data/deck_menu/reset_current_deck_2.tres"))
	DialogManager.hide_dialog()

## モンスターのアイコンがクリックされた時の処理
func _on_monster_icon_button_up(index: int) -> void:
	selected_slot_index_changed.emit(index)
	
	if monster_icon_container.get_child(index).data == null:
		parent.mode = parent.Mode.MONSTER_SELECT
	else:
		selected_monster_changed.emit(Global.player_deck.monster[index])
		parent.mode = parent.Mode.STATUS


func _on_line_edit_text_changed(new_text: String) -> void:
	Global.player_deck.name = new_text
