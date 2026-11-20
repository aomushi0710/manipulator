class_name BattleButton
extends Control

const MONSTER_NAME_LIMIT: int = 8 ## statusに表示する上での、モンスターの名前の上限文字数

@export var battle_node: Control
@export var action_container: VBoxContainer

var is_player_turn: bool = false

var now_showing: int ## 現在表示中のボタンメニュー[br]0:main 1:action 2:item 3:status 4:target 5:monsters
var now_player: bool ## true:現在playerの情報を表示 false:現在enemyの情報を表示
var monster: BattleMonster
var selected_action_button: ActionButton
var button_index: int
var selected_action: ActionData
var selected_item: Item
var is_victory: bool = false

var tween: Tween ## ボタンの出現と消失アニメーションに使用される[Tween]で、これが再生されている間は[member back_button]が反応しません
var action_tween: Tween ## [ActionButton]のアニメーションに使用される[Tween]

@onready var back_button := %Back as Button
@onready var change_button := %Change as MonsterIcon
@onready var dialog_tab := %DialogTab as TabContainer

@onready var main_buttons := %Main as Control
@onready var target_buttons := %Target as Control
@onready var item_buttons := %Item as Control
@onready var status_buttons := %Status as Control

func _ready() -> void:
	for button in main_buttons.get_children() as Array[Button]:
		button.disabled = true
	
	for button in status_buttons.get_children() as Array[Button]:
		button.disabled = true
	
	back_button.disabled = true
	now_showing = 0
	change_button.data = Global.player_deck.monster[0].data
	change_button.form = Global.player_deck.monster[0].form
	
	# item生成
	# TODO 今後、デッキに3つまでアイテムを設定できるようにする。その3つのアイテムについて繰り返す
	var pos: float = 0 ## 変動するposition.xカウンタ
	for key in SaveManager.save_data.item:
		var button := ItemButton.new()
		button.disabled = true
		button.position.x = pos
		button.scale = Vector2(0.781, 0.781)
		button.item = Global.item_data[key]
		button.texture_normal = button.item.image
		button.button_up.connect(func(): 
			await  hide_item_button()
			show_item_target_button(button.item))
		item_buttons.add_child(button)
		pos += 210 # 右にずらす

## 技の対象を選ぶ必要がある時に表示されるボタンを生成する関数
func _on_action_button_selected(index: int) -> void:
	back_button.disabled = true
	button_index = index
	
	selected_action_button = action_container.get_child(index).duplicate()
	selected_action = selected_action_button.action
	selected_action_button.name = "SelectedActionButton"
	selected_action_button.scale = action_container.scale
	selected_action_button.position = action_container.get_child(index).global_position - global_position
	selected_action_button.size.x = action_container.get_child(index).size.x
	add_child(selected_action_button)
	
	await hide_action_button()
	# ボタン移動アニメーション
	action_tween = selected_action_button.create_tween()
	action_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_EXPO)
	action_tween.tween_property(selected_action_button, "position:y", 802, 0.5)
	await action_tween.finished
	
	await show_target_button()
	if battle_node.back_disabled == false:
		back_button.disabled = false
	
	# ボタン点滅アニメーション
	action_tween = selected_action_button.create_tween()
	action_tween.set_loops()
	action_tween.tween_property(selected_action_button, "modulate:a", 0, 0.5)
	action_tween.tween_property(selected_action_button, "modulate:a", 1, 0.5)
	
	_set_action_description_text()

## 技の説明テキストをダイアログに表示します
func _set_action_description_text() -> void:
	var descriptions: Array[String] = _action_description_creator(selected_action, true)
	var description_text: Array[String] = ["[i][u]%s[/u][/i]\n%s　　MP Cost:[color=aqua]%d[/color]\n" % 
		[selected_action.name, descriptions[0], selected_action.mp] + 
		"%s　　Power　:[color=red]%d[/color]" % [descriptions[1], selected_action.power]]
	
	if selected_action.ability.is_empty():
		dialog_tab.text_setter(BattlelogData.new(description_text, false))
	else:
		var ability_description: Array = [null] ## 特殊効果説明画像のリスト
		for ability: Ability in selected_action.ability:
			description_text.append(ability.description)
			var abi_des := Global.ABILITY_DESCRIPTION.instantiate() as AbilityDescription
			abi_des.ability = ability
			ability_description.append(abi_des)
		
		dialog_tab.text_setter(BattlelogData.new(
			description_text, false, BattlelogData.Tab.MAIN, ability_description
		))

## [member main_buttons]のActionが押された時
func _on_action_button_up() -> void:
	await hide_main_button()
	show_action_button()

## [member main_buttons]のItemが押された時
func _on_item_button_up() -> void:
	await hide_main_button()
	show_item_button()

## [member main_buttons]のStatusが押された時
func _on_status_button_up() -> void:
	await hide_main_button()
	show_status_button()

## StatusのPlayerStatusが押された時
func _on_player_status_button_up() -> void:
	await hide_status_button()
	show_monsters_button(true)

## StatusのEnemyStatus
func _on_enemy_status_button_up() -> void:
	await hide_status_button()
	show_monsters_button(false)

## メインボタン出現アニメーション
func show_main_button() -> void:
	back_button.disabled = true
	now_showing = 0
	main_buttons.show()
	
	tween = main_buttons.create_tween() # ボタン出現アニメーション
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_buttons, "position:y", 865, 0.5)
	await tween.finished
	
	# プレイヤーのターンでないとボタンを使用できない
	if is_player_turn:
		for button in main_buttons.get_children() as Array[Button]:
			button.disabled = false
	
	# メインボタンのため戻るボタンを有効化する必要なし

## メインボタン消失アニメーション
func hide_main_button() -> void:
	for button in main_buttons.get_children() as Array[Button]:
		button.disabled = true
	
	tween = main_buttons.create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(main_buttons, "position:y", 1020, 0.5)
	await tween.finished
	
	main_buttons.hide()
	
	if battle_node.back_disabled == false:
		back_button.disabled = false

## action出現アニメーション
func show_action_button() -> void:
	now_showing = 1
	if battle_node.tutorial_mode == false:
		dialog_tab.text_setter(BattlelogData.new(["技を選んでください！\nクリックで技の詳細を確認できます。"], false))
		
	for button in action_container.get_children() as Array[ActionButton]:
		button.modulate.a = 0
	
	action_container.show()
	action_tween = action_container.create_tween()
	for child in action_container.get_children():
		action_tween.tween_property(child, "modulate:a", 1, 0.2)
	await action_tween.finished
	
	if battle_node.back_disabled == false:
		back_button.disabled = false

## action消滅アニメーション
func hide_action_button() -> void:
	for button in action_container.get_children() as Array[ActionButton]:
		button.disabled = true
	
	tween = action_container.create_tween()
	tween.tween_property(action_container, "modulate:a", 0, 0.2)
	await tween.finished
	
	action_container.hide()
	action_container.modulate.a = 1
	
	## [ActionButton]の表示は通常と異なるアニメーションのため、この時点で利用可能にしておく
	for button in action_container.get_children() as Array[ActionButton]:
		button.disabled = false

## item出現アニメーション
func show_item_button() -> void:
	now_showing = 2
	dialog_tab.text_setter(BattlelogData.new([
		"アイテムを選んでください！\n1回のバトル中に1回だけ使えます。"
	], false))
	item_buttons.show()
	tween = get_tree().create_tween().bind_node(item_buttons)
	tween.tween_property(item_buttons, "position:y", 865, 0.5)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	for child: ItemButton in item_buttons.get_children(): # 使用可能
		child.disabled = child.is_used # 使用済みなら押せないまま
	if battle_node.back_disabled == false:
		back_button.disabled = false

## item消滅アニメーション
func hide_item_button() -> void:
	for child: ItemButton in item_buttons.get_children(): # 使用不可
		child.disabled = true
	tween = get_tree().create_tween().bind_node(item_buttons)
	tween.tween_property(item_buttons, "position:y", 1020, 0.5)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await  tween.finished
	item_buttons.hide()
	if battle_node.back_disabled == false:
		back_button.disabled = false

## target出現アニメーション
func show_target_button() -> void:
	now_showing = 4
	await target_button_setting()

## target消滅アニメーション
func hide_target_button() -> void:
	if action_tween and action_tween.is_running():
		action_tween.kill()
	
	for child in target_buttons.get_children():
		if child is TextureButton:
			child.disabled = true
		elif child is Button:
			child.queue_free()
	
	# ボタン消滅アニメーション
	tween = target_buttons.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(target_buttons, "position:y", 1020, 0.5)
	await tween.finished
	
	target_buttons.hide()

## 味方か相手を選択させるボタン出現アニメーション
func show_status_button() -> void:
	now_showing = 3
	if battle_node.tutorial_mode == false:
		dialog_tab.text_setter(BattlelogData.new(["Player Status で味方のステータスを、\nEnemy  Status で相手のステータスを\n確認できます！"], false))
	
	status_buttons.show()
	
	tween = status_buttons.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(status_buttons, "position:y", 865.0, 0.5).from(1020.0)
	await tween.finished
	
	for button in status_buttons.get_children() as Array[Button]:
		button.disabled = false
	
	if not battle_node.back_disabled:
		back_button.disabled = false

## 味方か相手を選択させるボタン消滅アニメーション
func hide_status_button() -> void:
	back_button.disabled = true
	for button in status_buttons.get_children() as Array[Button]:
		button.disabled = true
	
	tween = status_buttons.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(status_buttons, "position:y", 1020.0, 0.5).from(865.0)
	await tween.finished
	
	status_buttons.hide()

## デッキモンスター一覧ボタン出現アニメーション
func show_monsters_button(is_player: bool) -> void:
	now_showing = 5
	dialog_tab.text_setter(BattlelogData.new([
		"モンスターをクリックして、\nステータスを確認してください！"
	], false))
	now_player = is_player
	
	var deck: Deck
	if is_player:
		deck = Global.player_deck
	else:
		deck = Global.enemy_deck
	
	for i in range(3):
		var target_button := target_buttons.get_child(i) as TextureButton
		target_button.texture_normal = deck.monster[i].get_monsterform().image
		target_button.modulate.v = 1.0
		
	target_buttons.show()
	
	tween = get_tree().create_tween().bind_node(target_buttons)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(target_buttons, "position:y", 865, 0.5)
	await tween.finished
	
	for child: TextureButton in target_buttons.get_children():
		child.disabled = false
	if battle_node.back_disabled == false:
		back_button.disabled = false

## デッキモンスター一覧ボタン消滅アニメーション
func hide_monsters_button() -> void:
	back_button.disabled = true
	for child: TextureButton in target_buttons.get_children():
		child.disabled = true
	tween = get_tree().create_tween().bind_node(target_buttons)\
	.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target_buttons, "position:y", 1020, 0.5)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	target_buttons.hide()

## アイテム使用先を選ぶtarget出現アニメーション
func show_item_target_button(item: Item) -> void:
	now_showing = 6
	selected_item = item
	dialog_tab.text_setter(BattlelogData.new([
		"[b]%s Lv.%d[/b]\n%s" % 
		[item.name, item.get_level(), 
		item.get_battle_description(item.get_level())]
	], false))
	
	await target_button_setting()

## アイテム使用先を選ぶtarget消滅アニメーション
func hide_item_target_button() -> void:
	for child in target_buttons.get_children():
		child.disabled = true
	# ボタン消滅アニメーション　ツリーのポーズを無視
	tween = get_tree().create_tween().bind_node(target_buttons)\
	.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(target_buttons, "position:y", 1020, 0.5)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	target_buttons.hide()

## 戻るボタンが押された場合の、各種状態での挙動
func _on_back_button_up() -> void: # 戻る連打によるバグの発生をdisacleで阻止
	if tween and tween.is_running():
		return
	
	back_button.disabled = true
	match now_showing:
		-1: # バトル終了後、デッキセレクトに戻る
			battle_finished() # 初期化処理を呼ぶ
		1:
			if battle_node.tutorial_mode == false:
				dialog_tab.flavor_text_setter()
			await hide_action_button()
			show_main_button()
		
		2: # 戻る アイテム選択 -> メイン
			if battle_node.tutorial_mode == false:
				dialog_tab.flavor_text_setter()
			await hide_item_button()
			show_main_button()
		
		3: # 戻る 味方か相手選択 -> メイン
			if battle_node.tutorial_mode == false:
				dialog_tab.flavor_text_setter()
			await hide_status_button()
			show_main_button()
		
		4: # 戻る ターゲット選択 -> 技選択
			if action_tween and action_tween.is_running(): # ボタン点滅アニメーション停止
				action_tween.kill()
			
			# ボタン消滅アニメーション
			tween = selected_action_button.create_tween()
			tween.tween_property(selected_action_button, "modulate:a", 0, 0.2)
			await tween.finished
			selected_action_button.queue_free()
			
			await hide_target_button()
			show_action_button()
		
		5: # 戻る モンスター一覧 -> 味方か相手選択
			await hide_monsters_button()
			show_status_button()
		
		6: # 戻る ターゲット選択 -> アイテム選択
			await hide_item_target_button()
			show_item_button()

## 対象から必要なtarget候補を割り出し、生死を加味して表示する関数
func target_button_setting() -> void:
	for child in target_buttons.get_children():
		child.modulate = Color(1, 1, 1)
	
	var death_list: Array[bool] = \
	[Global.e1_death, Global.e2_death, Global.e3_death, \
	Global.p1_death, Global.p2_death, Global.p3_death] # for文用真理値配列
	var target: Enums.Target ## match文に利用する数値
	match now_showing:
		4: # 技の対象選択時
			if selected_action.target == Enums.Target.なし:
				target = selected_action.ability[0].target
			else:
				target = selected_action.target
		6: # アイテムの対象選択時
			target = selected_item.target
	
	var disable_list: Array[bool] = [] ## ボタンが押せるかどうかのboolを格納するリスト
	if battle_node.tutorial_mode == true:
		match target:
			Enums.Target.近接, Enums.Target.遠隔, \
			Enums.Target.敵全体, Enums.Target.敵味方全体:
				target_buttons.get_child(0).texture_normal = \
				load("res://asset/image/monster/カカシスライム.PNG")
				disable_list.append(false)
				for i in range(1, 3):
					target_buttons.get_child(i).texture_normal = \
					load("res://asset/image/null.PNG")
					disable_list.append(true)
	
	else:
		match target: # 攻撃対象ごとに生成する画像が違う
			Enums.Target.近接, Enums.Target.遠隔, \
			Enums.Target.敵全体, Enums.Target.敵味方全体:
				for i in range(3):
					var disable: bool = true ## そのボタンのdisabledのbool
					
					if death_list[i] == true:
						target_buttons.get_child(i).texture_normal = load("res://asset/image/grave_stone.PNG")
					
					elif Global.enemy_deck.monster[i].data == null:
						target_buttons.get_child(i).texture_normal = load("res://asset/image/null.PNG")
					
					else:
						target_buttons.get_child(i).texture_normal = \
						Global.enemy_deck.monster[i].get_monsterform().image
						disable = false
					# 近接の時、場にいないモンスターは暗くし、押せなくする
					if (target == Enums.Target.近接 and
						battle_node.enemy_deck[i].on_field == false):
						target_buttons.get_child(i).modulate = Color(0.5, 0.5, 0.5)
						disable = true
					
					disable_list.append(disable)
			
			Enums.Target.自分, Enums.Target.味方単体, Enums.Target.味方全体:
				for i in range(3):
					var disable: bool = true ## そのボタンのdisabledのbool
					
					if death_list[i + 3] == true:
						target_buttons.get_child(i).texture_normal = load("res://asset/image/grave_stone.PNG")
					
					elif Global.player_deck.monster[i].data == null:
						target_buttons.get_child(i).texture_normal = load("res://asset/image/null.PNG")
					
					else:
						target_buttons.get_child(i).texture_normal = \
						Global.player_deck.monster[i].get_monsterform().image
						disable = false
					# 近接の時、場にいないモンスターは暗くし、押せなくする
					if (target == Enums.Target.自分 and
						battle_node.player_deck[i].on_field == false):
						target_buttons.get_child(i).disabled = true
						target_buttons.get_child(i).modulate = Color(0.5, 0.5, 0.5)
						disable = true
					
					disable_list.append(disable)
	
	target_buttons.show()
	tween = get_tree().create_tween().bind_node(target_buttons)
	tween.tween_property(target_buttons, "position:y", 865, 0.5)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	if battle_node.tutorial_mode == true:
		for child in target_buttons.get_children(): # いかなるボタンも使用不可
			if child is TextureButton:
				child.disabled = true
	else: # 最後にボタンを使用可能にするが、disable_listによって使用不可にする
		for i in range(3):
			target_buttons.get_child(i).disabled = disable_list[i]
	if battle_node.back_disabled == false:
		back_button.disabled = false


func _on_escape_button_up() -> void: # 逃げるボタン処理 TODO 逃げられないバトル用の処理なども作る
	var selected_index: int = -1
	if battle_node.tutorial_mode == true:
		selected_index = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/battle/tutorial_end.tres"))
	else:
		selected_index = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/battle/battle_escape.tres"))
	
	if selected_index == 0:
		battle_finished()
	DialogManager.hide_dialog()

## バトル終了初期化処理
func battle_finished() -> void:
	Global.p1_death = false
	Global.p2_death = false
	Global.p3_death = false
	Global.e1_death = false
	Global.e2_death = false
	Global.e3_death = false
	get_tree().paused = false
	
	Global.player_deck.battle_finished()
	Global.enemy_deck.battle_finished()
	
	Global.enemy_deck.deck_creator(false) # 敵デッキ生成
	
	battle_node.battle_finished.emit(is_victory)


func _on_target_1_button_up() -> void:
	match now_showing:
		4: # 技の対象を選んだ時の動作
			target_button_up(0)
		5: # ステータスの確認対象を選んだ時の動作
			status_dialog(0)
		6: # アイテムの対象を選んだ時の動作
			item_target_button_up(0)

func _on_target_2_button_up() -> void:
	match now_showing:
		4:
			target_button_up(1)
		5:
			status_dialog(1)
		6:
			item_target_button_up(1)

func _on_target_3_button_up() -> void:
	match now_showing:
		4:
			target_button_up(2)
		5:
			status_dialog(2)
		6:
			item_target_button_up(2)

## 発動する技とそのターゲットが確定した時、各種情報をまとめて引数を渡す関数
func target_button_up(i: int) -> void:
	if action_tween and action_tween.is_running(): # ボタン点滅アニメーション停止
		action_tween.kill()
	
	back_button.disabled = true
	
	for child in target_buttons.get_children():
		child.disabled = true
	
	# 選ばれた技ボタン消滅アニメーション
	tween = selected_action_button.create_tween()
	tween.tween_property(selected_action_button, "modulate:a", 0, 0.5)
	await tween.finished
	
	if selected_action_button:
		selected_action_button.queue_free()
	
	battle_node.command_selected(monster, selected_action, i)
	
	await hide_target_button()
	show_main_button() # 最初の表示に戻す ボタンは利用不可のまま
	
	monster.generated_action.remove_at(button_index) # TODO 不要かも？
	monster.available_action.remove_at(button_index) # モンスターの技一覧から消す


func item_target_button_up(i: int) -> void:
	back_button.disabled = true
	for child in target_buttons.get_children():
		child.disabled = true
	
	get_parent().item_selected(true, monster, selected_item, i)
	
	await hide_item_target_button()
	show_main_button()
	# 一度使用したアイテムを使用不可にする
	for child: ItemButton in item_buttons.get_children():
		if child.item == selected_item:
			child.modulate.v = 0.5
			child.is_used = true # 使用済みにする

## モンスターのステータスをダイアログにセットして表示します
func status_dialog(i: int) -> void:
	var mon: Monster
	if now_player == true:
		mon = Global.player_deck.monster[i]
	else:
		mon = Global.enemy_deck.monster[i]
	
	await dialog_tab.text_setter(BattlelogData.new([
		mon.get_monsterform().name + "\n" + 
		"[color=coral]HP :%3d[/color] " % mon.maxHP + 
		" [color=aqua]MP :%3d  /  %3d[/color] " % [mon.supplyMP, mon.maxMP] +
		" [color=orange]ATK:%3d[/color] " % mon.ATK + 
		" [color=light_blue]DEF:%3d[/color]\n" % mon.DEF + 
		"[color=green]SPD:%3d[/color] " % mon.SPD + 
		" [color=aqua] (supply / max)[/color] " + 
		" [color=dodger_blue]MAG:%3d[/color] " % mon.MAG + 
		" [color=violet]RES:%3d[/color]" % mon.RES
	], true, BattlelogData.Tab.STATUS))

## [ActionData]を引数として、バトルダイアログに表示する文字列を返します
func _action_description_creator(act: ActionData, blank: bool) -> Array[String]:
	var range_text: String ## 技の対象
	var range_tip: String ## 技の対象の補足
	var range_blank: String = "" ## 技の対象表示の空白
	var dmg_type_text: String ## 技のステータス参照先
	var dmg_type_tip: String ## 技のステータス参照先の補足
	var dmg_type_blank: String ## 技のステータス参照先表示の空白
	
	match act.target:
		Enums.Target.なし:
			range_text = "なし"
			range_tip = "発動対象が存在しません"
		Enums.Target.近接:
			range_text = "近接"
			range_tip = "場に出ている敵に技を発動します。"
		Enums.Target.遠隔:
			range_text = "遠隔"
			range_tip = "場に出ているかどうかに関わらず敵に技を発動します。"
		Enums.Target.敵全体:
			range_text = "敵全体"
			range_tip = "敵全体に技を発動します。"
		Enums.Target.自分:
			range_text = "自分"
			range_tip = "自分に技を発動します。"
		Enums.Target.味方単体:
			range_text = "味方単体"
			range_tip = "味方単体に技を発動します。"
		Enums.Target.味方全体:
			range_text = "味方全体"
			range_tip = "味方全体に技を発動します。"
		Enums.Target.敵味方全体:
			range_text = "敵味方全体"
			range_tip = "敵味方全体に技を発動します。"
		_:
			range_text = "[color=red][b]ERROR[/b][/color]"
			range_tip = ""
	
	match act.damage_type:
		ActionData.DamageType.なし:	
			dmg_type_text = "なし"
			dmg_type_tip = "いずれのステータスも参照されません"
			dmg_type_blank = "　　"
		ActionData.DamageType.物理:
			dmg_type_text = "[color=red]物理[/color]"
			dmg_type_tip = "自身のATKと相手のDEFを参照します"
			dmg_type_blank = "　　"
		ActionData.DamageType.魔法:
			dmg_type_text = "[color=dodger_blue]魔法[/color]"
			dmg_type_tip = "自身のMAGと相手のRESを参照します"
			dmg_type_blank = "　　"
		_:
			dmg_type_text = "[color=red][b]ERROR[/b][/color]"
			dmg_type_tip = ""
	
	if blank == true and len(range_text) < 4: # 空白補完
		for i in 4 - len(range_text):
			range_blank += "　"
	
	range_text = "[hint=%s]対象:[color=yellow]%s[/color][/hint]" % [range_tip, range_text]
	dmg_type_text = "[hint=%s]分類:%s[/hint]" % [dmg_type_tip, dmg_type_text]
	
	if blank == true:
		dmg_type_text += dmg_type_blank
		range_text += range_blank
	
	return [dmg_type_text, range_text]
