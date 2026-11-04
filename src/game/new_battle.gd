extends Control

## 死亡時に交代するモンスターが選ばれるまで待つawait用シグナル
signal changed
## バトル終了シグナル。[br]勝利時は[code]true[/code]を返します。
signal battle_finished(is_victory: bool)

## チュートリアル用:バトル開始カットイン完了シグナル
signal cutin_ended
## チュートリアル用:プレイヤーモンスター行動可能シグナル
signal player_ready
## チュートリアル用:モンスター行動完了シグナル
signal command_ended

const MONSTER_SCENE = preload("res://scene/component/battle_monster.tscn")
const PLAYER_MONSTER_POSITION := Vector2(500, 350)
const ENEMY_MONSTER_POSITION := Vector2(1164, 350)

const PLAYER_MONSTER_START_POSITION := Vector2(-256, 350)
const ENEMY_MONSTER_START_POSITION := Vector2(1920, 350)

var tween: Tween
var player_next_index: int = 0 ## 次にチェンジするモンスターのindex
var enemy_next_index: int = 0
var player_deck: Array[BattleMonster]
var enemy_deck: Array[BattleMonster]
var player_monster: BattleMonster
var enemy_monster: BattleMonster
var tutorial_mode: bool = false ## true:チュートリアル
var back_disabled: bool = false ## 全ての戻るボタンが true:使用不可 false:使用可能

@onready var player_deck_control := %PlayerDeck as Control
@onready var enemy_deck_control := %EnemyDeck as Control
@onready var player_deck_container := %PlayerDeckContainer as HBoxContainer
@onready var enemy_deck_container := %EnemyDeckContainer as HBoxContainer

@onready var buttons := %Button as BattleButton
@onready var escape_button := %Escape as Button

@onready var continue_indicator := %ContinueIndicator as RichTextLabel

@onready var battle_start_label := %BattleStartLabel as RichTextLabel
@onready var result_background := %ResultBackground as ColorRect
@onready var win_label := %WinLabel as RichTextLabel
@onready var lose_label := %LoseLabel as RichTextLabel

@onready var se_battle := %SEBattle as BattleSoundEmitter
@onready var se_menu := %SEMenu as MenuSoundEmitter

func _ready() -> void:
	result_background.hide()
	win_label.hide()
	lose_label.hide()
	
	continue_indicator.hide()
	continue_indicator.modulate.a = 0
	
	escape_button.disabled = true
	escape_button.modulate.a = 0
	
	buttons.back_button.disabled = true
	buttons.back_button.modulate.a = 0
	
	buttons.change_button.modulate.a = 0
	buttons.main_buttons.position.y = 1080
	
	buttons.dialog_tab.modulate.a = 0
	buttons.dialog_tab.set_tab_disabled(1, true)
	buttons.dialog_tab.set_tab_disabled(2, true)
	
	battle_start_label.show()
	
	for button in buttons.main_buttons.get_children() as Array[Button]:
		button.disabled = true

# 味方と敵のデッキを準備
func setup() -> void:
	monster_setup()
	
	player_next_index = 2
	_on_change_button_up()
	
	await battle_start_animation()
	
	# シーン遷移アニメーション
	tween = self.create_tween() # monster出現アニメーション
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO).set_parallel()
	tween.tween_property($Player1, "position", PLAYER_MONSTER_POSITION, 0.5).from(PLAYER_MONSTER_START_POSITION)
	tween.tween_property($Enemy1, "position", ENEMY_MONSTER_POSITION, 0.5).from(ENEMY_MONSTER_START_POSITION)
	tween.tween_property(player_deck_control, "position:x", 0, 0.5)
	tween.tween_property(enemy_deck_control, "position:x", 1170, 0.5)
	await tween.finished
	
	player_monster.spd_bar.set_process(true)
	if not tutorial_mode:
		enemy_monster.spd_bar.set_process(true)
	
	if tutorial_mode == true:
		cutin_ended.emit()


func monster_setup() -> void:
	for deck in [Global.player_deck, Global.enemy_deck] as Array[Deck]:
		for i in len(deck.monster):
			var monster := MONSTER_SCENE.instantiate() as BattleMonster
			monster.index = i
			monster.data = deck.monster[i]
			monster.data.form = Monster.Form.第一形態
			monster.battle_node = self
			monster.text_setter_callback = Callable(buttons.dialog_tab, "text_setter")
			
			match deck:
				Global.player_deck:
					monster.is_player = true
					monster.name = "Player%d" % (i + 1)
					
					if i == 0:
						player_monster = monster
						monster.position = PLAYER_MONSTER_START_POSITION
						add_child(monster)
						monster.hp_label.show()
						monster.mp_label.show()
					else:
						player_deck_container.add_child(monster)
						monster.hp_label.hide()
						monster.mp_label.hide()
						monster.spd_bar.hide()
					
					player_deck.append(monster)
					monster.button_up.connect(monster_button_up.bind(monster.index))
				
				Global.enemy_deck:
					monster.is_player = false
					monster.mouse_filter = Control.MOUSE_FILTER_IGNORE
					monster.name = "Enemy%d" % (i + 1)
					
					if i == 0:
						enemy_monster = monster
						monster.position = ENEMY_MONSTER_START_POSITION
						add_child(monster)
						monster.hp_label.show()
						monster.mp_label.show()
					else:
						enemy_deck_container.add_child(monster)
						monster.hp_label.hide()
						monster.mp_label.hide()
						monster.spd_bar.hide()
					
					enemy_deck.append(monster)
			
			monster.spd_bar.set_process(false)
			monster.show()
			# シグナル接続
			# モンスター行動可能通知シグナル
			monster.monster_ready.connect(monster_ready.bind(monster.is_player))

## バトル開始カットインのアニメーション
func battle_start_animation() -> void:
	tween = self.create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(battle_start_label, "scale", Vector2(1.2, 1.2), 0.4).from(Vector2.ZERO)
	tween.tween_property(battle_start_label, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.25)
	
	tween.tween_property(battle_start_label, "modulate:a", 0.0, 0.25).from(1.0)
	tween.parallel().tween_property(battle_start_label, "scale", Vector2(1.2, 1.2), 0.25)
	tween.tween_interval(0.25)
	
	tween.set_parallel()
	tween.tween_property(escape_button, "modulate:a", 1, 0.5)
	tween.tween_property(buttons.back_button, "modulate:a", 1, 0.5)
	tween.tween_property(buttons.dialog_tab, "modulate:a", 1, 0.5)
	tween.tween_property(buttons.change_button, "modulate:a", 1, 0.5)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(buttons.main_buttons, "position:y", 865, 0.5)
	await tween.finished
	
	battle_start_label.hide()
	escape_button.disabled = false
	continue_indicator.show()
	
	if tutorial_mode == false:
		buttons.dialog_tab.now_flavor_text = BattlelogData.new(["ついにこの戦いが始まった。"], false)
		buttons.dialog_tab.text_setter(buttons.dialog_tab.now_flavor_text)

# spdgaugeが溜まり行動可能になった時
func monster_ready(is_player: bool) -> void:
	# spdゲージ停止
	player_monster.spd_bar.set_process(false)
	enemy_monster.spd_bar.set_process(false)
	if player_monster.spd_bar.value == enemy_monster.spd_bar.value:
		enemy_monster.spd_bar.value -= 10
	
	if is_player: # プレイヤーが行動可能になった時
		buttons.is_player_turn = true
		buttons.dialog_tab.set_tab_disabled(1, false)
		buttons.dialog_tab.set_tab_disabled(2, false)
		buttons.monster = player_monster # 現在フィールドにいるモンスターを渡す
		var original_mp: int = player_monster.data.MP ## MP回復前の値を保持しておく 
		player_monster.mp_setter(player_monster.data.supplyMP, false) # mp回復
		
		for button in buttons.action_container.get_children(): # 全てのボタンを一旦削除
			button.queue_free()
		# 抽選された技をactionコンテナに追加
		for i in len(player_monster.available_action):
			var instance := Global.ACTION_BUTTON.instantiate() as ActionButton
			buttons.action_container.add_child(instance)
			instance.action = player_monster.available_action[i].data
			instance.button_up.connect(select_command.bind(i))
		
		# 全てのボタン有効化
		for button in buttons.main_buttons.get_children() as Array[Button]:
			button.disabled = false
		# dialog更新
		if tutorial_mode == false:
			var text: Array[String] = set_ready_text(player_monster, original_mp)
			buttons.dialog_tab.text_setter(BattlelogData.new(text, false)) # 味方の時はコマンド選択を待つ
		else:
			player_ready.emit()
	else:
		var original_mp: int = enemy_monster.data.MP ## MP回復前の値を保持しておく
		enemy_monster.mp_setter(enemy_monster.data.supplyMP, false)
		
		enemy_next_index = get_random_index(false) # 相手側の次に行動するモンスターをランダムにチェンジ
		
		var text: Array[String] = set_ready_text(enemy_monster, original_mp)
		await buttons.dialog_tab.text_setter(BattlelogData.new(text))
		
		var button_index := randi() % 4 # 味方モンスターと同じ変数名を使用
		var action := enemy_monster.available_action[button_index]
		var action_index: int = enemy_target_select(action)
		
		command_selected(enemy_monster, action.data, action_index)
		enemy_monster.available_action.remove_at(button_index)

## [param resource]([code]Action[/code]及び[code]Ability[/code])を基に[br]
##敵が行うターゲット選択を自動で行い、そのindexを返す関数
func enemy_target_select(resource: Resource) -> int:
	if resource is not Action and resource is not Ability:
		print("ERROR:不明な型。-1を返します。")
		return -1
	
	# Action型は、中のActionData型を抜き出して利用する
	if resource is Action:
		resource = resource.data
	
	var index: int ## 返り値
	match resource.target:
		Enums.Target.なし: # 技の代わりに特殊効果の対象を選択する
			if resource is Action:
				index = enemy_target_select(resource.ability[0])
		
		Enums.Target.近接:
			index = player_monster.index
		
		Enums.Target.遠隔:
			index = get_random_index(true)
		
		Enums.Target.自分:
			index = enemy_monster.index
		
		Enums.Target.味方単体:
			index = get_random_index(false)
		
		Enums.Target.敵全体, Enums.Target.味方全体, Enums.Target.敵味方全体:
			index = -1
	
	return index

## 味方か敵かを指定し、生きている敵のindexをランダムに返します
func get_random_index(is_player: bool) -> int:
	var target_indexs: PackedInt32Array
	for i in range(3):
		if is_player:
			if not player_deck[i].is_died:
				target_indexs.append(i)
		else:
			if not enemy_deck[i].is_died:
				target_indexs.append(i)
	
	if target_indexs.is_empty():
		return -1
	
	return target_indexs[randi() % target_indexs.size()]

## モンスターを引数として、そのモンスターが行動可能になった時に表示されるテキストを返す関数
## 引数mpは、mpが自動回復する前に保持されていたmp。比較用に利用する
func set_ready_text(monster: BattleMonster, mp: int) -> Array[String]:
	var mp_text: String = "" ## 自動MP回復によるテキスト
	if mp < monster.data.maxMP:
		if (monster.data.maxMP - mp) < monster.data.supplyMP:
			mp_text = "%s は[color=aqua]MP[/color]が[color=aqua]%d[/color]回復した！" % [monster.data.get_monsterform().name, monster.data.maxMP - mp]
		else:
			mp_text = "%s は[color=aqua]MP[/color]が[color=aqua]%d[/color]回復した！" % [monster.data.get_monsterform().name, monster.data.supplyMP]
	
	var text: String ## 敵か味方かで変わるテキスト
	if monster.is_player == true:
		text = "[color=yellow]%s は指示を待っている...[/color]" % monster.data.get_monsterform().name
	else:
		text = "[color=yellow]相手の %s の行動！[/color]" % monster.data.get_monsterform().name
	
	return ["%s が行動可能になった。\n%s\n%s" % [monster.data.get_monsterform().name, mp_text, text]]

## ターン終了後にフィールドに立つモンスターのindexと画像を設定します
func _on_change_button_up() -> void:
	if player_deck[0].is_died and player_deck[1].is_died and player_deck[2].is_died:
		return
	
	while true: # 生きているモンスターになるまで自動で繰り返す
		match player_next_index:
			0, 1:
				player_next_index += 1
			2:
				player_next_index = 0
		
		if player_deck[player_next_index].is_died == false:
			break
	
	buttons.change_button.data = Global.player_deck.monster[player_next_index].data
	buttons.change_button.form = Global.player_deck.monster[player_next_index].form
	if player_monster.index != player_next_index:
		changed.emit()

## モンスターのボタンを押して、ターン終了後にフィールドに立つモンスターのindexと画像を設定します
func monster_button_up(i: int) -> void:
	if player_deck[i].is_died == false: # 生きてたら
		player_next_index = i
		if player_monster.index != player_next_index:
			buttons.change_button.data = Global.player_deck.monster[player_next_index].data
			buttons.change_button.form = Global.player_deck.monster[player_next_index].form
			changed.emit()

## buttonスクリプト接続用関数
func select_command(i: int) -> void:
	buttons._on_action_button_selected(i)

## [param monster]が[param action]を発動する関数[br]
## 発動対象は[param monster]が味方か敵かどうかと[param index]によって、
## [code]target_setting[/code]関数を用いて決定される。[br][br]
## この関数が特殊効果[code]AbilityExtra[/code]によって呼ばれる場合、
## [param extra]は[code]true[/code]で呼ぶ。(デフォルトは[code]false[/code])
func command_selected(monster: BattleMonster, action: ActionData, index: int, 
extra: AbilityExtra = null) -> void:
	buttons.is_player_turn = false
	buttons.dialog_tab.set_tab_disabled(1, true)
	buttons.dialog_tab.set_tab_disabled(2, true)
	
	# 味方または相手が全滅している時
	if (
		(Global.e1_death and Global.e2_death and Global.e3_death) or 
		(Global.p1_death and Global.p2_death and Global.p3_death)
	):
		return
	
	monster.spd_bar.value = 0
	
	# 発動可能な技かどうかチェック
	if await action_checker(monster, action) == false:
		turn_end(monster)
		return
	
	var dialog_text: Array[String] = [] ## ダイアログに表示するテキストを収納する
	var damage: int ## 与えたダメージの記録用
	
	 # mp消費処理
	if action.mp > 0:
		dialog_text.append(monster.mp_setter(-action.mp, true))
		monster.mp_used.emit(action.mp)
	# AbilityExtraによって発動した技かどうかで表示メッセージを変える
	if extra == null:
		dialog_text.append("%s の %s！" % 
		[monster.data.get_monsterform().name, action.name])
	else:
		dialog_text.append(extra.battle_log_message)
	
	await buttons.dialog_tab.text_setter(BattlelogData.new(dialog_text))
	
	# 進化技の時
	if action.id == 10001 or action.id == 10002:
		dialog_text = monster.evolution(action.id)
		await buttons.dialog_tab.text_setter(BattlelogData.new(dialog_text))
	
	# 全ての特殊能力について順番に処理
	for i in len(action.ability):
		if action.ability[i].timing == Ability.Timing.前:
			await execute_ability(monster, action.ability[i], index)
	
	# 攻撃をする技なら
	if action.power > 0:
		var target_list := target_setting(monster.is_player, action, index)
		
		for target: BattleMonster in target_list: # 対象にダメージをあたえる
			var damage_array = damage_calc(action, monster, target)
			damage = damage_array[0]
			dialog_text.clear()
			var text := target.hp_setter(-damage, true)
			text += "\n%s" % damage_array[1] # ダメージ相性のテキストを追加
			dialog_text.append(text)
			await buttons.dialog_tab.text_setter(BattlelogData.new(dialog_text))
	
			if target.data.HP <= 0: # 死亡時処理
				await target.dead(player_monster, enemy_monster)
	
	# 全ての特殊能力について順番に処理
	for i in len(action.ability):
		if action.ability[i].timing == Ability.Timing.後:
			await execute_ability(monster, action.ability[i], index, damage)
	
	# AbilityExtraによって発動した技ならばそのまま元の処理に戻り、そうでないならターン終了
	if extra == null:
		turn_end(monster)

## [param monster]と[param action]を基に何らかの理由で発動できない技の場合に中断する関数。[br]
## 発動可能な技の場合[code]true[/code]を返し、発動不可な技の場合[code]false[/code]を返す。
func action_checker(monster: BattleMonster, action: ActionData) -> bool:
	# 第1形態から最終形態にスキップするのを防止
	if not await evolution_action_checker(monster, action):
		return false
	# mpが足りない場合
	if monster.data.MP < action.mp:
		await buttons.dialog_tab.text_setter(BattlelogData.new([
			"%s の %s！\n[color=yellow]しかし、[color=aqua]MP[/color]が足りない！[/color]" % 
			[monster.data.get_monsterform().name, action.name]
		]))
		return false
	
	return true

## 進化が現在の形態で可能かどうかを調べる関数
func evolution_action_checker(monster: BattleMonster, action: ActionData) -> bool:
	match monster.data.form:
		Monster.Form.第一形態:
			if action.id > 10001:
				await buttons.dialog_tab.text_setter(BattlelogData.new([
					"[color=yellow]%s はまだ第3形態には進化できない！[/color]\n" % 
					monster.data.get_monsterform().name +
					"先に第2形態に進化してください！"
				]))
				return false
	
	return true

## 特殊効果[param ability]を発動する関数[br]
## [param monster]はその技を発動したモンスター[br]
## [param index]でどの敵が対象かを割り出す[code]target_setting[/code]関数を呼び出す[br]
## 後で発動するabilityの場合は、[param damage]を利用することがある。デフォルトは0
func execute_ability(monster: BattleMonster, ability: Ability, index: int, 
damage: int = 0) -> void:
	if randi() % 100 + 1 > ability.chance: # 確率範囲外ならその効果の処理スキップ
		return
	
	var target_list := target_setting(monster.is_player, ability, index)
	
	for target in target_list: # 全ての対象について順番に処理
		if ability is AbilityEffect: # 状態異常 TODO 未実装
			pass
		
		elif ability is AbilityBuff or ability is AbilityDebuff: # バフ or デバフ
			## abilityを基に作られた、モンスターに付与されるエフェクト
			var monster_effect := MonsterEffect.new(ability)
			var has_same_effect: bool = false ## 同じエフェクトが付与されているかどうか
			
			for me: MonsterEffect in target.effect_list: # 既に対象が持つエフェクトに対して
				if monster_effect.effect == me.effect: # 同じものが見つかれば
					me.turn += monster_effect.turn # ターン数を延長する
					has_same_effect = true
					break
			
			if has_same_effect == false: # 同じエフェクトが見つからなかった時、新たに追加
				target.add_effect(monster_effect)
				if monster == target: # 自分自身に追加した場合、1ターン余分に消費されることを防止する
					monster_effect.is_just_applied_to_self = true
			
			var damage_text = Global.DAMAGE_TEXT.instantiate()
			damage_text.text = "[font_size=50][b][i]%s[/i][/b][/font_size]" % \
			ability.bbcode_name.replace(" ", "\n")
			target.add_child(damage_text)
			
			if ability is AbilityBuff: # バフ効果音
				se_battle.buff.play()
			elif ability is AbilityDebuff: # デバフ効果音
				se_battle.debuff.play()
			
			var text: String
			if ability.battle_log_message == "":
				text = "これは...どうやら開発者がメッセージを\n入れ忘れているらしい。" + \
				"\nそれでも特殊効果は発動した！"
			else:
				text = ability.battle_log_message % \
				target.data.get_monsterform().name
			await buttons.dialog_tab.text_setter(BattlelogData.new([text]))
		
		elif ability is AbilityHealing: # 回復
			var heal: int ## 回復量
			var monster_max_gauge: int ## 技を放ったモンスターのゲージ最大値
			var target_max_gauge: int ## 技の対象モンスターのゲージ最大値
			match ability.status:
				AbilityHealing.Status.HP:
					monster_max_gauge = monster.data.maxHP
					target_max_gauge = target.data.maxHP
				
				AbilityHealing.Status.MP:
					monster_max_gauge = monster.data.maxMP
					target_max_gauge = target.data.maxMP
				
				AbilityHealing.Status.SPD:
					monster_max_gauge = SpeedBar.SPD_GAUGE_MAX_VALUE
					target_max_gauge = SpeedBar.SPD_GAUGE_MAX_VALUE
			
			match ability.amount_type:
				AbilityHealing.AmountType.定数:
					heal = ability.amount
				
				AbilityHealing.AmountType.MAG:
					heal = monster.data.MAG * ability.amount
				
				AbilityHealing.AmountType.吸収:
					heal = damage * ability.amount
				
				AbilityHealing.AmountType.最大ゲージ割合:
					heal = monster_max_gauge * ability.amount
				
				AbilityHealing.AmountType.最大ゲージ割合_対象:
					heal = target_max_gauge * ability.amount
				
				_:
					print("不明な列挙型AbilityHealing -> AmountType。0を返します。")
					heal = 0
			
			var dialog_text: String = "" ## 表示するテキスト
			if ability.battle_log_message != "":
				dialog_text = ability.battle_log_message + "\n"
			
			match ability.status:
				AbilityHealing.Status.HP:
					dialog_text += target.hp_setter(heal, true)
				
				AbilityHealing.Status.MP:
					dialog_text += target.mp_setter(heal, true)
				
				AbilityHealing.Status.SPD:
					target.spd_bar.value += SpeedBar.SPD_GAUGE_MAX_VALUE * ability.amount
					dialog_text += "%s は %d%%加速した!" % [target.data.get_monsterform().name, ability.amount * 100]
			
			await buttons.dialog_tab.text_setter(BattlelogData.new([dialog_text]))
		
		elif ability is AbilityExtra: # 連続攻撃
			await command_selected(monster, ability.action, index, ability)


func item_selected(is_player: bool, monster: BattleMonster, item: Item, index: int) -> void:
	buttons.is_player_turn = false
	buttons.dialog_tab.set_tab_disabled(1, true)
	buttons.dialog_tab.set_tab_disabled(2, true)
	# アイテム名10文字以下なら1行で表示可能
	await buttons.dialog_tab.text_setter(BattlelogData.new([
		"%s Lv.%dを使った！" % [item.name, item.get_level()]
	]))
	var target_list: Array[BattleMonster] = target_setting(is_player, item, index)
	for target: BattleMonster in target_list:
		match item.id:
			1: # ライフポーション
				await item_animation(item, target)
				var text: String = target.hp_setter( # 最終的には小数点切り捨て
					target.data.maxHP * (item.get_power(item.get_level()) / 100.0), true)
				await buttons.dialog_tab.text_setter(BattlelogData.new([text]))
			2: # マナポーション
				await item_animation(item, target)
				var text: String = target.mp_setter( # 最終的には小数点切り捨て
					target.data.maxMP * (item.get_power(item.get_level()) / 100.0), true)
				await buttons.dialog_tab.text_setter(BattlelogData.new([text]))
	
	turn_end(monster)

## アイテム使用時のアニメーションを再生する関数
func item_animation(item: Item, monster: BattleMonster) -> void:
	match item.id:
		1, 2: # ライフポーション、マナポーション
			# ポーションを投げてモンスターに当てるアニメーション
			var item_node = TextureRect.new()
			item_node.texture = item.image
			item_node.position = Vector2(500, 350)
			item_node.pivot_offset = item_node.size / 2
			add_child(item_node)
			var item_tween: Tween = item_node.create_tween().bind_node(item_node)
			item_tween.tween_property(item_node, "rotation_degrees", 360, 0.5)
			item_tween.parallel().tween_property(item_node, "position:y", 222, 0.5)
			item_tween.parallel().tween_property(item_node, "scale", Vector2(0.8, 0.8), 0.5)
			item_tween.parallel().tween_property(item_node, "modulate:a", 0.8, 0.5)
			item_tween.tween_callback(func(): item_node.rotation_degrees = -360)
			item_tween.tween_property(item_node, "rotation_degrees", 360, 1)
			item_tween.parallel().tween_property(item_node, "position", monster.position, 1)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			item_tween.parallel().tween_property(item_node, "scale", Vector2(0.4, 0.4), 1)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			item_tween.parallel().tween_property(item_node, "modulate:a", 0, 1)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			await item_tween.finished
			item_node.queue_free()

## モンスターの行動終了時の処理
func turn_end(monster: BattleMonster) -> void:
	# 相手全滅
	if Global.e1_death == true and Global.e2_death == true and Global.e3_death == true:
		return
	# 味方全滅
	elif Global.p1_death == true and Global.p2_death == true and Global.p3_death == true:
		return
	
	for effect: MonsterEffect in monster.effect_list: # エフェクト効果を引き起こす
		effect.turn_finished()
	
	# モンスター交代
	if monster.is_player == true and player_monster != player_deck[player_next_index]:
		player_monster.set_bench() # フィールドのモンスターをベンチに
		player_monster = player_deck[player_next_index]
		player_monster.set_field() # 次に指定されたモンスターをフィールドに
	elif monster.is_player == false and enemy_monster != enemy_deck[enemy_next_index]:
		enemy_monster.set_bench()
		enemy_monster = enemy_deck[enemy_next_index]
		enemy_monster.set_field()
	
	if not player_monster.is_died:
		player_monster.spd_bar.set_process(true)
	if not tutorial_mode:
		if not enemy_monster.is_died:
			enemy_monster.spd_bar.set_process(true)
	
	if monster.is_player: # 味方モンスターが動いた後にのみフレーバーテキスト更新
		## 選ばれるフレーバーテキスト一覧の候補
		var flavor_text_table = [
			buttons.dialog_tab.global_flavor_text,
			buttons.dialog_tab.stage_flavor_text,
			player_monster.data.get_monsterform().flavor_text,
			enemy_monster.data.get_monsterform().flavor_text
		]
		## [code]flavor_text_table[/code]のそれぞれに対応した重みづけテーブル
		var weight_table_table = [
			buttons.dialog_tab.global_flavor_text_weight,
			buttons.dialog_tab.stage_flavor_text_weight,
			player_monster.data.get_monsterform().flavor_text_weight,
			enemy_monster.data.get_monsterform().flavor_text_weight
		]
		## [code]flavor_text_table[/code]の重みづけテーブル
		var weight_table: Array[int]= [1, 2, 1, 1]
		
		# 配列が空の時、候補から削除しておくことでエラーを防止する。
		for i in range(flavor_text_table.size() - 1, -1, -1):
			if flavor_text_table[i].is_empty():
				flavor_text_table.remove_at(i)
				weight_table_table.remove_at(i)
				weight_table.remove_at(i)
		
		var index = Global.get_weighted_random(weight_table)
		## 選ばれるフレーバーテキストの候補
		var available_flavor_text = flavor_text_table[index]
		
		var flavor_text: BattlelogData = available_flavor_text[
			Global.get_weighted_random(weight_table_table[index])
		]
		buttons.dialog_tab.now_flavor_text = flavor_text
	
	if tutorial_mode == false:
		buttons.dialog_tab.text_setter(buttons.dialog_tab.now_flavor_text) # フレーバーテキスト設定
	else:
		command_ended.emit()

## バトル終了処理 win true:勝利 false:敗北
func battle_finish(is_victory: bool) -> void:
	buttons.is_victory = is_victory
	buttons.now_showing = -1
	result_background.show()
	if is_victory:
		var coins: int = 0 ## 合計コイン枚数
		for i in range(3): # コイン獲得
			coins += enemy_deck[i].data.data.coin
		SaveManager.add_coins(coins)
		win_label.show()
		buttons.dialog_tab.text_setter(BattlelogData.new([
			"[b][color=red]勝利！[/color][/b]\n" +
			"[color=gold]%dコイン[/color]を手に入れた！\n" % coins +
			"左下の戻るボタンを押してバトルを終了"
		], false))
		
	else:
		lose_label.show()
		buttons.dialog_tab.text_setter(BattlelogData.new([
			"[b][color=dodger_blue]敗北...[/color][/b]\n\n" +
			"左下の戻るボタンを押してバトルを終了 "
		], false))

## 選ばれた敵または味方の[param index]を基にして技・特殊効果・アイテム[param resource]
## の発動先をリストにして返す関数[br]
## [param is_player]発動者がプレイヤーなら[code]true[/code]、敵なら[code]false[/code]。
func target_setting(is_player: bool, resource: Resource, index: int
) -> Array[BattleMonster]:
	var target_list: Array[BattleMonster] = [] # 特殊効果の発動対象
	
	# 技でも特殊効果でもアイテムでもなければ中断
	if resource is not ActionData and resource is not Ability and resource is not Item:
		print("不明な型です")
		return []
	
	if is_player:
		match resource.target:
			Enums.Target.近接:
				for mon in enemy_deck:
					if mon.on_field:
						target_list.append(mon)
						break
			
			Enums.Target.遠隔:
				target_list.append(enemy_deck[index])
			
			Enums.Target.敵全体:
				for mon in enemy_deck:
					if not mon.is_died:
						target_list.append(mon)
			
			Enums.Target.自分:
				for mon in player_deck:
					if mon.on_field:
						target_list.append(mon)
						break
			
			Enums.Target.味方単体:
				target_list.append(player_deck[index])
			
			Enums.Target.味方全体:
				for mon in player_deck:
					if not mon.is_died:
						target_list.append(mon)
			
			Enums.Target.敵味方全体:
				for deck: Array[BattleMonster] in [enemy_deck, player_deck]:
					for mon in deck:
						if not mon.is_died:
							target_list.append(mon)
	else:
		match resource.target:
			Enums.Target.近接:
				for mon in player_deck:
					if mon.on_field:
						target_list.append(mon)
						break
			
			Enums.Target.遠隔:
				target_list.append(player_deck[index])
			
			Enums.Target.敵全体:
				for mon in player_deck:
					if not mon.is_died:
						target_list.append(mon)
			
			Enums.Target.自分:
				for mon in enemy_deck:
					if mon.on_field:
						target_list.append(mon)
						break
			
			Enums.Target.味方単体:
				target_list.append(enemy_deck[index])
			
			Enums.Target.味方全体:
				for mon in enemy_deck:
					if not mon.is_died:
						target_list.append(mon)
			
			Enums.Target.敵味方全体:
				for deck: Array[BattleMonster] in [player_deck, enemy_deck]:
					for mon: BattleMonster in deck:
						if not mon.is_died:
							target_list.append(mon)
	
	return target_list

## 属性倍率計算機(1属性)
func attribute(o: int,d: int):
	if ( # 0:無 1:火 2:水 3:雷 4:土 5:風 6:氷 7:光 8:闇
		(o == 2 and d == 1) or (o == 3 and d == 2) or (o == 4 and d == 3) or 
		(o == 5 and d == 4) or (o == 6 and d == 5) or (o == 1 and d == 6) or 
		(o == 7 and d == 8) or (o == 8 and d == 7)):
		return 2.0 # 弱点を突いたときダメージ2倍
	elif (
		(o == 1 and d == 2) or (o == 2 and d == 3) or (o == 3 and d == 4) or 
		(o == 4 and d == 5) or (o == 5 and d == 6) or (o == 6 and d == 1) or 
		(o == d and o != 0)):
		return 0.5 # 得意属性もしくは同じ属性の技を受けた時ダメージ0.5倍
	elif o == 0 and d != 0:
		return 0.8 # 無属性でない敵に無属性の技で攻撃する際の軽減倍率0.8倍
	else:
		return 1.0 # その他等倍

## 属性倍率計算機(反復)
func attribute_setup(action: ActionData, monster: Monster) -> float:
	var magnification: float = 1.0 # 最終的な属性相性倍率
	for act_element: Element in action.element:
		for monster_element: Element in monster.get_monsterform().element:
			magnification *= attribute(act_element.id, monster_element.id)
	return magnification

## ダメージ計算機[br]戻り値array[ダメージ(int), 属性相性テキスト(string)]
func damage_calc(action: ActionData, offense: BattleMonster, defense: BattleMonster)\
 -> Array:
	if action.power == 0: # powerが0なら不要なので中断
		return [0, ""]
	
	var status: Array[float] = [0, 0] # ステータス値
	var type: Array[Enums.Status] = []
	type.resize(2)
	match action.damage_type: # 必要なステータス参照
		ActionData.DamageType.なし:
			pass
		
		ActionData.DamageType.物理:
			status[0] = offense.data.ATK
			status[1] = defense.data.DEF
			type[0] = Enums.Status.ATK
			type[1] = Enums.Status.DEF
		
		ActionData.DamageType.魔法:
			status[0] = offense.data.MAG
			status[1] = defense.data.RES
			type[0] = Enums.Status.MAG
			type[1] = Enums.Status.RES
		
		_:
			print("ERROR:damage_typeが検知できません")
	
	# エフェクトをステータスに対応させる処理
	var effects_list = [offense.effect_list, defense.effect_list]
	for i in range(2): # i=0:攻撃側ステータスについて i=1:守備側ステータスについて
		for effect: MonsterEffect in effects_list[i]:
			var ability = effect.effect
			if ability is AbilityBuff: # バフ
				if type[i] == ability.status: # 計算に用いるステータスと一致している時
					status[i] *= ability.amount
			
			elif ability is AbilityDebuff: # デバフ
				if type[i] == ability.status: # 計算に用いるステータスと一致している時
					status[i] /= ability.amount
	
	var magnification: float = attribute_setup(action, defense.data)
	var magnification_text: String = ""
	if magnification < 1.0:
		magnification_text = "[color=light_blue]耐性があるようだ...[/color]\n"
	elif magnification > 1.0:
		magnification_text = "[color=red]弱点をついた！[/color]\n"
	# power * ((攻撃側ステータス / 守備側ステータス) ** ステータス乖離ボーナス(1.2) * 属性相性
	var damage = action.power * ((status[0] / status[1]) ** 1.2) * magnification
	# モンスターと技の属性一致倍率を乗算
	var break_mode: bool = false # 2回目のbreak用
	for i: Element in action.element:
		for j: Element in offense.data.get_monsterform().element:
			if i == j:
				damage *= 1.5
				break_mode = true
				break
		if break_mode == true:
			break
	
	for ability: Ability in action.ability:
		if randi() % 100 + 1 > ability.chance: # 確率範囲外ならその効果の処理スキップ
			continue
		if ability is AbilityCritical:
			match ability.amount_type:
				AbilityCritical.AmountType.加算:
					damage += ability.amount
				
				AbilityCritical.AmountType.乗算:
					damage *= ability.amount
			
			magnification_text += ability.battle_log_message
		
		elif ability is AbilityFumble:
			match ability.amount_type:
				AbilityFumble.AmountType.減算:
					damage -= ability.amount
				
				AbilityFumble.AmountType.除算:
					damage /= ability.amount
		
			magnification_text += ability.battle_log_message
	
	return [int(damage), magnification_text]
