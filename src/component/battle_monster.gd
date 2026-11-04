class_name BattleMonster
extends TextureButton

signal monster_ready ## モンスターが行動可能になった時発行されます
@warning_ignore("unused_signal") # 親ノードがこのシグナルを発行するため
signal mp_used(amount: int) ## モンスターがMPを使用した時発行されます
signal evolved ## モンスターが進化した時発行されます
signal died ## モンスターが死亡した時発行されます

const EFFECT_ICON = preload("res://scene/component/effect_icon.tscn")

@export var battle_node: Control ## TODO 今後親ノードを知らずにシグナルアップのみで解決する設計に変更する

var tween: Tween
var is_player: bool ## このモンスターは味方かどうか
var index: int
var on_field: bool ## このモンスターが場に出ているかどうか
var data: Monster: ## モンスターの現在の状態 INFO バトル中に更新される場合あり
	set(value):
		data = value
		ui_update()

var effect_list: Array[MonsterEffect] = [] ## エフェクトが格納される配列
var is_died: bool = false
var text_setter_callback: Callable ## dialogのtext_setter
var chance_range: Array[int] ## 抽選に用いる範囲
var generated_action: Array[Action] ## 乱数による抽選で生成された技の配列
var available_action: Array[Action] ## 実際に表示される選択可能な技の配列

@onready var monster_icon := %MonsterIcon as MonsterIcon
@onready var name_label := %CenteredWrapper/Name as RichTextLabel
@onready var effect_container := %Effect as HBoxContainer

@onready var hp_bar := %HPBar as TextureProgressBar
@onready var hp_label := %HPBar/Amount as Label
@onready var mp_bar := %MPBar as TextureProgressBar
@onready var mp_label := %MPBar/Amount as Label
@onready var spd_bar := %SPDBar as SpeedBar

@onready var se_battle := %SEBattle as BattleSoundEmitter

func _ready() -> void:
	setup()
	if index == 0:
		on_field = true
	else:
		on_field = false
	hide()
	
	ui_update()

## UI全般の更新を行う関数
func ui_update() -> void:
	if not is_node_ready():
		return
	
	hp_bar.max_value = data.maxHP
	hp_bar.value = data.HP
	hp_label.text = "HP %3d/%3d" % [data.HP, data.maxHP]
	
	mp_bar.max_value = data.maxMP
	mp_bar.value = data.MP
	mp_label.text = "MP %3d/%3d" % [data.MP, data.maxMP]
	
	spd_bar.monster = data
	
	name_label.text = "[b][i]%s[/i][/b]" % data.get_monsterform().name
	texture_normal = load("res://asset/image/grave_stone.PNG") as Texture2D
	monster_icon.data = data.data
	monster_icon.form = data.form

# バトル開始時セットアップ
func setup() -> void:
	# 初期値を設定
	data.HP = data.maxHP
	data.MP = data.maxMP / 5
	
	ui_update()
	# 進化技、中間進化技の置換は技がランダムで選ばれる処理の中で行われるようにする
	
	# chance_range 生成
	var sum_range: int = 0
	for i in len(data.chance):
		var range: int = data.chance[i]
		if i == 0:
			range -= 1
		sum_range += range # ex.1:10% 2:20% 3:30% 4:40%なら、[9,29,59.99]となり、
		chance_range.append(sum_range) # 乱数0~9の範囲で1が、10~29で2、30~59で3、60~99で4

## 死亡処理
func dead(player_monster: BattleMonster, enemy_monster: BattleMonster) -> void:
	died.emit()
	
	get_tree().paused = true
	# フラグ立て
	is_died = true
	if is_player:
		match index:
			0:
				Global.p1_death = true
			1:
				Global.p2_death = true
			2:
				Global.p3_death = true
	else:
		match index:
			0:
				Global.e1_death = true
			1:
				Global.e2_death = true
			2:
				Global.e3_death = true
	effect_list.clear() # エフェクト全消し
	effect_container.blink_stop()
	# 死亡アニメーション
	tween = monster_icon.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(monster_icon, "modulate:a", 0, 0.5)
	await tween.finished
	
	spd_bar.set_process(false) # 死んだモンスターを停止
	spd_bar.value = 0
	# 相手全滅
	if Global.e1_death == true and Global.e2_death == true and Global.e3_death == true:
		battle_node.battle_finish(true)
		battle_node.buttons.back_button.disabled = false
		get_tree().paused = false
		return
	# 味方全滅
	elif Global.p1_death == true and Global.p2_death == true and Global.p3_death == true:
		battle_node.battle_finish(false)
		battle_node.buttons.back_button.disabled = false
		get_tree().paused = false
		return
	# フィールドにいる味方モンスターがやられた時
	if is_player == true and self == player_monster:
		text_setter_callback.call(BattlelogData.new(["[color=red]%s はやられてしまった！[/color]\n" % data.get_monsterform().name + "次にフィールドに出すモンスターを\n選んでください。"], false))
		await battle_node.changed
		set_bench() # 死んだモンスターをベンチにセット
		battle_node.player_monster = battle_node.player_deck[battle_node.player_next_index] # 次のモンスターを設定
		battle_node.player_monster.set_field() # 次のモンスターをフィールドにセット
		battle_node.player_monster.spd_bar.set_process(true) # 交代後のモンスターを再開
	# フィールドにいる敵モンスターを倒した時、ランダムに次を選ぶ
	elif not is_player and self == enemy_monster:
		await text_setter_callback.call(BattlelogData.new([
			"[color=red]%s を倒した！[/color]\n" % data.get_monsterform().name +
			"次にフィールドに出すモンスターを\n相手が選んでいる..."
		]))
		await get_tree().create_timer(1).timeout # 考えるフリ
		battle_node.enemy_next_index = battle_node.get_random_index(false)
		set_bench()
		battle_node.enemy_monster = battle_node.enemy_deck[battle_node.enemy_next_index]
		battle_node.enemy_monster.set_field()
	else:
		if is_player:
			await text_setter_callback.call(BattlelogData.new([
				"[color=red]%s はやられてしまった！[/color]\n" % 
				data.get_monsterform().name
			]))
		else:
			await text_setter_callback.call(BattlelogData.new([
				"[color=red]%s を倒した！[/color]\n" % 
				data.get_monsterform().name
			]))
	get_tree().paused = false

## 進化技を引数にして、そのIDにあった進化処理を施す
func evolution(id: int) -> Array[String]:
	var pre_monster_form := data.get_monsterform()
	var pre_maxHP := pre_monster_form.status_calculator(data.level)[0]
	if id == 10001: # 進化Ⅰ
		data.form = Monster.Form.第二形態
	elif id == 10002: # 進化Ⅱ
		data.form = Monster.Form.第三形態
	
	# hpを引き継ぐ時、進化で伸びたmaxHPの差だけ回復する
	hp_setter(data.maxHP - pre_maxHP, false)
	ui_update()
	
	se_battle.evolution.play()
	
	evolved.emit()
	
	return [
	"[color=red]%s は \n%s に\n進化した！[/color]" % 
	[pre_monster_form.name, data.get_monsterform().name], 
	"進化によって %s の\n[color=coral]HP[/color]が[color=green]%d[/color]回復した！" % 
	[data.get_monsterform().name, data.maxHP - pre_maxHP]]

## ベンチにモンスターをセットする時の処理[br]spdゲージは溜まらない
func set_bench() -> void:
	on_field = false
	hp_label.hide()
	mp_label.hide()
	spd_bar.hide()
	if is_player:
		reparent(battle_node.player_deck_container)
	else:
		reparent(battle_node.enemy_deck_container)

## フィールドにモンスターをセットする時の処理[br]1f待機後にspdゲージが溜まり始める
func set_field() -> void:
	on_field = true
	hp_label.show()
	mp_label.show()
	spd_bar.show()
	reparent(battle_node)
	scale = Vector2(1, 1)
	if is_player:
		position = Vector2(500, 350)
	else:
		position = Vector2(1164, 350)

## SPDゲージが溜まり行動可能になった時の処理
func _on_spd_bar_gauge_filled() -> void:
	# picked_action 生成
	if battle_node.tutorial_mode == false:
		while len(generated_action) < 4: # 4枠全て技で埋まるまで繰り返す
			var result: int = randi_range(0, 99)
			for i in len(chance_range):
				if result <= chance_range[i]: # 乱数に応じて出現する技を決定
					generated_action.append(data.data.action[i])
					break # 対応する技があったら終了
	
	var generated_action_size: int = generated_action.size()
	available_action.resize(generated_action_size)
	
	for i in generated_action_size:
		var act: Action = generated_action[i]
		available_action[i] = act.evolution_check(data.data, data.form)
	
	monster_ready.emit()

## エフェクトアイコンの追加関数
func add_effect(monster_effect: MonsterEffect) -> void:
	effect_list.append(monster_effect)
	var icon := EFFECT_ICON.instantiate() as EffectIconButton
	icon.effect = monster_effect
	effect_container.add_child(icon)
	effect_icon_blink()

## エフェクトアイコンの点滅関数
func effect_icon_blink() -> void:
	if not effect_list.is_empty(): # 何かエフェクトがあれば
		if not effect_container.tween or (effect_container.tween and not effect_container.tween.is_running()):
			effect_container.blink() # エフェクトがあるがtweenが存在しない、もしくはtweenがあるが点滅していない時
	else:
		if effect_container.tween and effect_container.tween.is_running():
			effect_container.blink_stop() # エフェクトがないのにtweenが存在し、点滅している時

## MP変動処理関数(setter)[br]n:数値 text true:能動的でダイアログ表示 false:受動的でダイアログ非表示
func mp_setter(n: int, text: bool) -> String:
	var original_n: int = n # マイナスになるため補正されたが、元の数値を利用したい時
	
	if n > 0: # mpが回復した時、水色でアニメーション再生
		if data.MP >= data.maxMP: # 既にMPが最大値の時
			if text == true: # 技の効果やアイテムの使用時など何らかの反応が得たい時
				return (
					"[color=yellow]しかし、%s の" %
					data.get_monsterform().name +
					"[color=aqua]MP[/color]は\n減っていなかった...[/color]"
				)
			else:
				return ""
		elif data.MP + n >= data.maxMP: # 回復するとMPが最大値を越えてしまう時
			n = data.maxMP - data.MP
		damage_effect(n, 2)
	else: # MPを削られた時、dark_redでアニメーション再生
		if data.MP <= 0: # 何らかの原因で死亡時
			return ""
		damage_effect(-n, 3)
		if data.MP <= -n: # 残りMPを越えるダメージを受けた時
			n = -data.MP # MPがマイナスにならないように補正
	
	var mp_text := data.MP
	data.MP += n
	tween = get_tree().create_tween().bind_node(mp_bar)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(mp_bar, "value", data.MP, 0.5)
	tween.parallel().tween_method(mp_text_update, mp_text, data.MP, 0.5)
	
	var return_text: String # textを表示する処理
	if text == true: # 能動的にmpが変動した場合？
		if n > 0: # mpが回復した時、水色でアニメーション再生
			return_text = (
				"%s の[color=aqua]MP[/color]が[color=aqua]%d[/color]回復した！" %
				[data.get_monsterform().name, n]
			)
		else:
			return_text = (
				"%s は [color=aqua]%dMP[/color]を消費した..." %
				[data.get_monsterform().name, -n]
			)
		return return_text
	else: # 受動的にmpが変動した場合?
		if n > 0: # spdゲージがたまって、mpが回復した時
			return_text = ""
		else: # 相手の技やアイテムなどによってmpを無理やり減らされた時
			return_text = (
				"%s は [color=aqua]%dMP[/color]を失った！" %
				[data.get_monsterform().name, -original_n]
			)
		return return_text

## HP変動処理関数(setter)[br]n:数値 text true:ダイアログ表示 false:ダイアログ非表示
func hp_setter(n: int, text: bool) -> String:
	var original_n: int = n # 元の数値を保存したい時に
	
	if n > 0: # hpが回復した)時、緑色でアニメーション再生
		if data.HP >= data.maxHP: # 既にHPが最大値の時
			return (
				"[color=yellow]しかし、%s の" % data.get_monsterform().name +
				"[color=coral]HP[/color]は\n減っていなかった...[/color]"
			)
		elif data.HP + n >= data.maxHP: # 回復するとHPが最大値を越えてしまう時
			n = data.maxHP - data.HP
		damage_effect(n, 0)
		se_battle.heal.play()
	else: # ダメージを受けた時、オレンジ色でアニメーション再生
		if data.HP <= 0: # 何らかの原因で死亡時
			return ""
		damage_effect(-n, 1)
		se_battle.damage.play()
		if data.HP <= -n: # 残りHPを越えるダメージを受けた時
			n = -data.HP # HPがマイナスにならないように補正
	
	var hp_text := data.HP
	data.HP += n
	tween = get_tree().create_tween().bind_node(hp_bar)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(hp_bar, "value", data.HP, 0.5)
	tween.parallel().tween_method(hp_text_update, hp_text, data.HP, 0.5)
	
	var return_text: String # textを表示する処理
	if text == true:
		if n > 0: # hpが回復した時、緑色でアニメーション再生
			return_text = (
				"%s の[color=coral]HP[/color]が[color=green]%d[/color]回復した！" %
				[data.get_monsterform().name, n]
			)
		else:
			return_text = (
				"%s は[color=orange]%d[/color]ダメージを受けた！" %
				[data.get_monsterform().name, -original_n]
			)
	
	return return_text

## hp_setterからhp_textの変化アニメーション用 
func hp_text_update(hp: int) -> void:
	hp_label.text = "HP %3d/%3d" % [hp, data.maxHP]

## hp_setterからhp_textの変化アニメーション用 
func mp_text_update(mp: int) -> void:
	mp_label.text = "MP %3d/%3d" % [mp, data.maxMP]

## 増減した数値を視覚的に表示するエフェクトアニメーションを再生する関数
func damage_effect(dmg: int, type: int) -> void:
	var text := Global.DAMAGE_TEXT.instantiate() as RichTextLabel
	match type: # type引数の値によって色を変更する
		0: # HP回復処理
			text.self_modulate = Color.GREEN
		1: # HP減少処理
			text.self_modulate = Color.ORANGE
		2: # MP回復処理
			text.self_modulate = Color.AQUA
		3: # MP減少処理
			text.self_modulate = Color.DARK_RED
		_: # 不明な引数の場合
			text.self_modulate = Color.WHITE
	
	var font_size: int = 30 + 10 * len(str(dmg)) ## ダメージの桁数からサイズを求める
	text.text = "[font_size=%d][b][i]%d[/i][/b][/font_size]" % [font_size, dmg]
	add_child(text)
