extends Control

## 親の[member MenuMonster.selected_monster]変数に代入させるシグナル。[br]
## 返り値とするリソース[Monster]は親のsetterで複製されて渡される。
signal selected_monster_changed(monster: Monster)
signal connect_hover_signal(node: Node)

## 棒グラフの長さ1px辺りの表せる数値
const UNIT_SCALE: Array[float]= [20, 0.25, 0.25, 1, 5, 5, 5, 5]
const STATUS_BAR_TEXT: Array[String] = [
	"[color=coral]HP [font_size=2]                   [/font_size][/color]:%4d", 
	"[table=2][cell][font_size=20][color=aqua]MP\nmax   " + 
	"[/color][/font_size][/cell][cell][center]:%4d[/center][/cell]", 
	"[table=2][cell][font_size=20][color=aqua]MP\nsupply" + 
	"[/color][/font_size][/cell][cell][center]:%4d[/center][/cell]", 
	"[color=limegreen]SPD[font_size=2]                   [/font_size][/color]:%4d", 
	"[color=orange]ATK[font_size=2]                   [/font_size][/color]:%4d", 
	"[color=lightblue]DEF[font_size=2]                   [/font_size][/color]:%4d", 
	"[color=dodgerblue]MAG[font_size=2]                   [/font_size][/color]:%4d", 
	"[color=violet]RES[font_size=2]                   [/font_size][/color]:%4d"
	]

@export var parent: MenuMonster

@onready var monster_texture := %MonsterTexture as TextureRect
@onready var action_scroll_container := %ActionScrollContainer as ScrollContainer
@onready var action_container := %ActionContainer as VBoxContainer
@onready var pie_chart := %PieChart as PieChart

@onready var action_select := %ActionSelect as Control
@onready var slider := %ChanceSettingSlider as HSlider
@onready var spinbox := %ChanceSettingSpinBox as SpinBox
@onready var max_chance_label := %MaxChance as RichTextLabel

@onready var action_description := %ActionDescription as Control
@onready var power_label := %Power as RichTextLabel
@onready var mp_label := %Mp as RichTextLabel
@onready var type_label := %Type as RichTextLabel
@onready var target_label := %Target as RichTextLabel
@onready var unlock_condition_label := %UnlockCondition as RichTextLabel
@onready var ability_description_container := %AbilityDescriptionContainer as HBoxContainer

var text_speed: float = 0.05 ## テキストアニメーションの1文字あたりの再生速度
var selected_monster: Monster ## [member MenuMonster.selected_monster]を参照
var selected_action: Action ## 現在選択中の技
var selected_skill: int = 0 ## 選ばれたスキルパターン
var now_select_action: int = 0 ## 現在指定されている技
var all_status_list: Array[PackedInt32Array] = []
var actions: Array[Action] = [] ## モンスターが持つ技
var chances: Array[int] = [] ## 選ばれた技の出現確率
var text_tween: Tween


func on_mode_entered() -> void:
	parent.camera.offset = Vector2(960, 540)
	
	# action_listの中身を削除
	for child in action_container.get_children():
		child.queue_free()
	
	# 進化プレビュー選択肢追加
	parent.evolution_preview_button.clear()
	for i in len(selected_monster.data.evolution_forms):
			parent.evolution_preview_button.add_item(Monster.form_names[i], i)
	
	# セーブデータ読み込み
	if selected_monster.data.id in SaveManager.save_data.monster_levels:
		parent.level_spinbox.value = \
		SaveManager.save_data.monster_levels[selected_monster.data.id]
	else:
		parent.level_spinbox.value = 1
	# モンスターを表示
	monster_preview()
	
	actions = selected_monster.data.action.duplicate()
	# すでに登録されているものと同じモンスターを選んだ場合、その技をロード
	if (Global.player_deck.monster[parent.selected_slot_index].data != null and 
		Global.player_deck.monster[parent.selected_slot_index].data.id == 
		selected_monster.data.id):
		chances = Global.player_deck.monster[parent.selected_slot_index].chance.duplicate()
	else:
		chances.clear()
		chances.resize(len(actions))
	
	# 円グラフ生成
	pie_chart_update()
	
	setting_action_button()

## モンスターの各形態のプレビュー表示を更新する関数[br]
## [param is_text_only]が[code]false[/code]の時、棒グラフがアニメーションされる。
func monster_preview(is_text_only: bool = false) -> void:
	if selected_monster.data.evolution_forms.is_empty():
		return
	
	# 棒グラフのアニメーションが終わるまで押せなくする
	parent.evolution_preview_button.disabled = true
	
	monster_texture.texture = selected_monster.get_monsterform().image
	monster_texture.get_child(0).get_child(0).monster = (
		selected_monster.get_monsterform())
	monster_texture.get_child(0).get_child(1).text = (
		"[b][i]%s[/i][/b]" % selected_monster.get_monsterform().name)
	
	bar_chart_update(is_text_only)

## ステータス棒グラフ更新関数[br]
## ## [param is_text_only]が[code]false[/code]の時、棒グラフがアニメーションされる。
func bar_chart_update(is_text_only: bool = false) -> void:
	## 表示したいモンスターのステータス一覧
	var status_list: PackedInt32Array = all_status_list[selected_monster.form]
	var status_index: int = 0 ## status_listのindex指定用
	for child in parent.status_bar.get_child(0).get_children():
		for c in child.get_children():
			if c is RichTextLabel: # ステータス値表示
				c.text = STATUS_BAR_TEXT[status_index]
				c.text = c.text % status_list[status_index]
			
			elif c is TextureRect: # バー生成
				if is_text_only:
					continue
				
				if c.name == "bar": # 元からあるbarだけ処理
					# TODO 長さの表現は修正の余地あり
					var current_bar: TextureRect = c
					for i in range(selected_monster.form + 1):
						var new_bar: TextureRect ## バー本体
						var bar_length: int ## バーの長さ
						if i == 0: # 第一形態の時、元のバーのみ処理
							new_bar = current_bar
							bar_length = (
								all_status_list[i][status_index] / 
								UNIT_SCALE[status_index]
							)
							new_bar.custom_minimum_size.x = 0
						else: # 新たなバーを生成
							new_bar = bar_chart_bar_duplicate(current_bar)
							bar_length = (
								(all_status_list[i][status_index] - 
								all_status_list[i - 1][status_index]) / 
								UNIT_SCALE[status_index]
							)
							child.add_child(new_bar)
						
						# アニメーションさせる
						if (parent.mode == parent.Mode.ACTION or 
							i == selected_monster.form):
							bar_chart_animation(new_bar, bar_length)
						else: # 他は既にセットされている
							new_bar.custom_minimum_size.x = bar_length
						
						current_bar = new_bar
				else: # 増えたbarは消す
					c.queue_free()
		status_index += 1

## 棒グラフに用いる[param bar]ノードのサイズ[param size_x]及び色を変更して複製された、
##新たなbarを返す関数
func bar_chart_bar_duplicate(bar: TextureRect, size_x: int = 0) -> TextureRect:
	var new_bar := bar.duplicate() as TextureRect
	new_bar.custom_minimum_size.x = size_x
	new_bar.texture = new_bar.texture.duplicate(true) as Texture2D
	var gradient: Gradient = new_bar.texture.gradient
	var original_color := gradient.colors[1]
	original_color.v -= 0.25
	gradient.colors = [Color.WHITE, original_color]
	return new_bar

## 棒グラフの指定した[param bar]ノードを伸ばしたい量[param final_val]まで
##アニメーションさせる関数。[br]
## またアニメーション終了後に、進化プレビューボタンを押せる状態に戻します。[br]
## [param callback]引数を受け取ると、アニメーション終了後に呼び出します。
func bar_chart_animation(bar: TextureRect, final_val: int, 
callback: Callable = Callable()) -> void:
	var tween: Tween
	tween = get_tree().create_tween().bind_node(bar)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(bar, "custom_minimum_size:x", final_val, 1)
	tween.tween_callback(parent.evolution_preview_button.set.bind("disabled", false))
	
	if callback.is_valid():
		tween.tween_callback(callback)

## 選択中の技出現確率円グラフ更新関数
func pie_chart_update() -> void:
	var float_chances: Array[float]
	float_chances.assign(chances)
	pie_chart.actions = Global.action_to_actiondata(actions)
	pie_chart.chances = float_chances
	pie_chart.queue_redraw()

## 全ての[Action]を[ActionSettingButton]として追加する関数
func setting_action_button() -> void:
	for i in len(actions):
		var button := Global.ACTION_SETTING_BUTTON.instantiate() as ActionSettingButton
		button.action = actions[i]
		# is_lockedはsetter内でactionの情報を取得するため、actionより後で設定
		if selected_monster.level < actions[i].unlock_level:
			button.is_locked = true
		else:
			button.is_locked = false
		# chanceはis_lockedの設定時に上書きされてしまうため、is_lockedより後で設定
		action_container.add_child(button)
		button.chance = selected_monster.chance[i]
		button.action_button.action_button_up.connect(action_button_up.bind(button.is_locked))
		button.delete_button_up.connect(_on_action_button_delete_button_up)
		button.get_child(1).set_meta("help_text", "クリックで技の詳細を確認できます。")
		
	
	connect_hover_signal.emit(action_scroll_container)

## 技ボタンが押された時の関数
## [param is_not_editable]が[code]true[/code]の時、確率の操作ができないように
##一部ノードを使用不可にする。
func action_button_up(act: ActionData, is_not_editable: bool = false) -> void:
	for child in ability_description_container.get_children(): # 初期化
		child.queue_free()
	
	if parent.mode != parent.Mode.ACTION: # まだ移動していなければカメラ移動
		parent.mode = parent.Mode.ACTION
	
	if act == null: # nullなら移動だけして中断
		return
	
	action_select.show() # nullじゃなければ表示
	action_description.show()
	
	var index: int = -1
	for i in actions.size():
		if actions[i].data == act:
			index = i
			break
	
	selected_action = actions[index]
	## 元々ボタンがあれば取得される
	var exists := action_select.get_node_or_null("action_button")
	if exists: # 存在したら削除
		action_select.remove_child(exists)
		exists.queue_free()
	
	## 新たに表示されるボタン
	var button := Global.ACTION_BUTTON.instantiate() as ActionButton
	action_select.add_child(button)
	button.name = "action_button"
	button.position = Vector2(160, 20)
	button.action = act
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW # カーソルも戻す
	button.set_meta("help_text", act.description)
	parent.help_label.connect_hover_signal(button)
	
	if is_not_editable: # 確率表記を隠し、sliderとspinboxを操作不能に
		for child in action_select.get_children():
			if child is Range:
				child.editable = false
				if child is HSlider:
					child.tick_count = 0
			elif child is RichTextLabel:
				child.hide()
	else:
		for node: Range in [slider, spinbox]: # sliderとspinboxのセッティング
			# この時点では、先に設定していた技の最大値を、次に選ばれた技の確率が越えていた場合に、
			# 最大値に引っかかってしまう
			node.set_value_no_signal(chances[actions.find(selected_action)])
			node.max_value = float(act.max_chance)
			# もう一度値を設定して、適切な値に戻す
			node.set_value_no_signal(chances[actions.find(selected_action)])
			max_chance_label.text = "%d%%" % act.max_chance
			node.editable = true
		slider.tick_count = slider.max_value / 10 + 1
		
		for child in action_select.get_children():
			child.show()
	
	power_label.text = "[color=red]Power[/color]:%4d" % act.power
	mp_label.text = "[color=aqua]MP   [/color]:%4d" % act.mp
	
	match act.damage_type: # 分類によってテキストと枠線を変える
		ActionData.DamageType.なし:
			type_label.text = "分類:なし"
			var style: StyleBoxFlat = type_label.get_theme_stylebox("normal")
			style.border_color = Color.WHITE
			type_label.set_meta("help_text", "いずれのステータスも参照しません。")
		
		ActionData.DamageType.物理:
			type_label.text = "分類:[color=red]物理[/color]"
			var style: StyleBoxFlat = type_label.get_theme_stylebox("normal")
			style.border_color = Color.RED
			type_label.set_meta("help_text", 
			"攻撃側の[color=orange]ATK[/color]と" + \
			"守備側の[color=lightblue]DEF[/color]を参照します。")
		
		ActionData.DamageType.魔法:
			type_label.text = "分類:[color=dodger_blue]魔法[/color]"
			var style: StyleBoxFlat = type_label.get_theme_stylebox("normal")
			style.border_color = Color.DODGER_BLUE
			type_label.set_meta("help_text", 
			"攻撃側の[color=dodgerblue]MAG[/color]と" + \
			"守備側の[color=violet]RES[/color]を参照します。")
	
	match act.target: # 範囲によってテキストを変える
		Enums.Target.なし:
			target_label.text = "[color=yellow]対象[/color]:なし"
			target_label.set_meta("help_text", "ダメージを与えません。")
		
		Enums.Target.近接:
			target_label.text = "[color=yellow]対象[/color]:近接"
			target_label.set_meta("help_text", "場に出ている目の前の敵にダメージを与えます。")
		
		Enums.Target.遠隔:
			target_label.text = "[color=yellow]対象[/color]:遠隔"
			target_label.set_meta("help_text", "場に出ていない遠くの敵にもダメージを与えられます。")
		
		Enums.Target.敵全体:
			target_label.text = "[color=yellow]対象[/color]:敵全体"
			target_label.set_meta("help_text", "敵全体にダメージを与えます。")
		
		Enums.Target.自分:
			target_label.text = "[color=yellow]対象[/color]:自分"
			target_label.set_meta("help_text", "自分にダメージを与えます。")
		
		Enums.Target.味方単体:
			target_label.text = "[color=yellow]対象[/color]:味方単体"
			target_label.set_meta("help_text", "味方を1体だけ選んでダメージを与えます。")
		
		Enums.Target.味方全体:
			target_label.text = "[color=yellow]対象[/color]:味方全体"
			target_label.set_meta("help_text", "味方全体にダメージを与えます。")
		
		Enums.Target.敵味方全体:
			target_label.text = "[color=yellow]対象[/color]:敵味方全体"
			target_label.set_meta("help_text", "敵全体と味方全体にダメージを与えます。")
	
	## 技の解放条件を表示するテキスト
	var unlock_condition_text := "解放:Lv.%2d" % selected_action.unlock_level
	var unlock_condition_help := (
		"この技はLv.%dから使用可能になります。" % selected_action.unlock_level)
	if selected_action.unlock_form != Monster.Form.第一形態:
		unlock_condition_text += (
			"\n[img=40]res://asset/image/element/進化技.PNG[/img]%s" % 
			Monster.form_names[selected_action.unlock_form]
		)
		unlock_condition_help += (
			"ただし[b]%s[/b]に進化するまでは使用できず、それまでは対応する" % 
			Monster.form_names[selected_action.unlock_form] + 
			"「[img=50]res://asset/image/element/進化技.PNG[/img]" + 
			"[color=yellow]進化技[/color]」に置き換えられ、" + 
			"これを発動することでモンスターが進化できます。" 
		)
	unlock_condition_label.text = unlock_condition_text
	unlock_condition_label.set_meta("help_text", unlock_condition_help)
	
	for ability: Ability in act.ability:
		var description := Global.ABILITY_DESCRIPTION.instantiate() as AbilityDescription
		description.ability = ability
		if ability is AbilityExtra:
			description.ability_extra_button_up.connect(action_button_up.bind(true))
		
		description.set_meta("help_text", ability.description)
		ability_description_container.add_child(description)
	
	parent.help_label.connect_hover_signal(action_description)

## [signal ActionSettingButton.delete_button_up]が発行された時、登録された技を削除し、UIを更新します
func _on_action_button_delete_button_up(action: Action) -> void:
	if selected_action == action:
		_on_chance_value_changed(0)
	else:
		chances[actions.find(action)] = 0
	
	pie_chart_update()

## slider及びspinboxの値が変更された時に、反映させる関数
func _on_chance_value_changed(value: int) -> void:
	var sum_chance: int = 0
	var index: int = actions.find(selected_action) ## 既に選択中の技のインデックス
	var previous_chances := chances.duplicate() as Array[int] ## 選択中の技を除いたchances
	var previous_value := previous_chances.pop_at(index) as int
	
	for i in previous_chances:
		sum_chance += i
	sum_chance += value
	
	if sum_chance > 100: # 100%を越える場合、元の値に差し戻し
		await DialogManager.set_text_dialog(preload("res://resource/dialog_data/monster_setting/chance_exceed_100.tres"))
		value = previous_value # 元の値に戻す
		DialogManager.hide_dialog()
	else:
		chances[index] = value # 技一覧の確率と円グラフを更新
		pie_chart_update()
	
	for node: Range in [slider, spinbox]: # sliderとspinboxを更新
		node.set_value_no_signal(value)
	
	var button := action_container.get_child(index) as ActionSettingButton
	button.chance = value

## おまかせボタンが押された時
func _on_random_button_up() -> void:
	selected_monster.random_action_selector()
	chances = selected_monster.chance
	pie_chart_update()
	
	for i in len(chances):
		if actions[i] == selected_action:
			_on_chance_value_changed(chances[i])
		else:
			var button := action_container.get_child(i) as ActionSettingButton
			button.chance = chances[i]


func _on_control_status_mode_confirm_button_up() -> void:
	selected_monster_changed.emit(selected_monster)
