extends Panel
class_name AbilityDescription
## [ActionData]が持つ[Ability]の詳細について表示するUI

signal ability_extra_button_up(act: ActionData) ## [AbilityExtra]の場合のみ表示される[ActionButton]が押された時に発行されます

@onready var background := %Background as TextureRect
@onready var name_label := %Name as RichTextLabel
@onready var target_label := %Target as RichTextLabel
@onready var chance_label := %Chance as RichTextLabel
@onready var ability_effect_ui := %AbilityEffect as Control ## AbilityEffectでのみ表示
@onready var ability_buff_ui := %AbilityBuff as Control ## AbilityBUff及びAbilityDebuffでのみ表示
@onready var ability_healing_ui := %AbilityHealing as Control ## AbilityHealing及びAbilityReductionでのみ表示
@onready var ability_critical_ui := %AbilityCritical as Control ## AbilityCritical及びAbilityFumbleでのみ表示
@onready var ability_extra_ui := %AbilityExtra as Control ## AbilityExtraでのみ表示

var ability: Ability

func _ready() -> void:
	background.texture = background.texture.duplicate(true)
	var gradient: Gradient = background.texture.gradient
	var amount_text: String ## [code]amount[/code]の値によって変わるテキスト
	if ability is AbilityEffect: # 状態異常
		pass # 未実装
	
	elif ability is AbilityBuff: # バフ
		gradient.colors = [Color.WHITE, Color.DARK_RED]
		# 不要なラベルを隠す
		for child in get_children():
			if child.get_class() == "Control":
				if child == ability_buff_ui:
					child.show()
				else:
					child.hide()
		
		var color_text: String ## ステータスに対応した色コード
		match ability.status:
			Enums.Status.ATK:
				color_text = "orange"
			
			Enums.Status.DEF:
				color_text = "light_blue"
			
			Enums.Status.MAG:
				color_text = "dodger_blue"
			
			Enums.Status.RES:
				color_text = "violet"
		
		## バフの倍率を表示するRichTextLabel
		var multiplier: RichTextLabel = ability_buff_ui.get_child(0)
		multiplier.text = (
			"[color=%s]倍率[/color]:%8.2f倍" % [color_text, ability.amount])
		
		var multiplier_style: StyleBoxFlat = multiplier.get_theme_stylebox("normal")
		multiplier_style.border_color = Color(color_text)
		
		## バフの持続ターン数を表示するRichTextLabel
		var turn: RichTextLabel = ability_buff_ui.get_child(1)
		if ability.turn == -1: # ターン数に-1が設定されていた場合は∞ターン
			turn.text = "[color=salmon]ターン[/color]:∞"
		else:
			turn.text = "[color=salmon]ターン[/color]:%2d" % ability.turn
		
		var turn_style: StyleBoxFlat = turn.get_theme_stylebox("normal")
		turn_style.border_color = Color.SALMON
	
	elif ability is AbilityDebuff: # デバフ
		gradient.colors = [Color.WHITE, Color.DARK_BLUE]
		# 不要なラベルを隠す
		for child in get_children():
			if child.get_class() == "Control":
				if child == ability_buff_ui:
					child.show()
				else:
					child.hide()
		
		var color_text: String ## ステータスに対応した色コード
		match ability.status:
			Enums.Status.ATK:
				color_text = "orange"
			
			Enums.Status.DEF:
				color_text = "light_blue"
			
			Enums.Status.MAG:
				color_text = "dodger_blue"
			
			Enums.Status.RES:
				color_text = "violet"
		
		## デバフの倍率を表示するRichTextLabel
		var multiplier: RichTextLabel = ability_buff_ui.get_child(0)
		multiplier.text = (
			"[color=%s]倍率[/color]:%8.2f倍" % [color_text, 1 / ability.amount])
		
		var multiplier_style: StyleBoxFlat = multiplier.get_theme_stylebox("normal")
		multiplier_style.border_color = Color(color_text)
		
		## バフの持続ターン数を表示するRichTextLabel
		var turn: RichTextLabel = ability_buff_ui.get_child(1)
		if ability.turn == -1: # ターン数に-1が設定されていた場合は∞ターン
			turn.text = "[color=cornflower_blue]ターン[/color]:∞"
		else:
			turn.text = "[color=cornflower_blue]ターン[/color]:%2d" % ability.turn
		
		var turn_style: StyleBoxFlat = turn.get_theme_stylebox("normal")
		turn_style.border_color = Color.CORNFLOWER_BLUE
	
	elif ability is AbilityHealing: # ゲージ回復
		# 不要なラベルを隠す
		for child in get_children():
			if child.get_class() == "Control":
				if child == ability_healing_ui:
					child.show()
				else:
					child.hide()
		
		var status_text: String ## [code]ability.status[/code]によって変わるテキスト
		var space_length: int ## 半角スペースの長さ
		match ability.status:
			AbilityHealing.Status.HP:
				gradient.colors = [Color.WHITE, Color.YELLOW_GREEN]
				status_text = "[color=coral]HP[/color][color=yellow_green]回復量[/color]:"
				space_length = 16
			
			AbilityHealing.Status.MP:
				gradient.colors = [Color.WHITE, Color.AQUA]
				status_text = "[color=aqua]MP回復量[/color]:"
				space_length = 16
			
			AbilityHealing.Status.SPD:
				gradient.colors = [Color.WHITE, Color.LIME_GREEN]
				status_text = "[color=lime_green]SPD増加量[/color]:"
				space_length = 15
		
		match ability.amount_type:
			AbilityHealing.AmountType.定数:
				amount_text = str(int(ability.amount))
			
			AbilityHealing.AmountType.吸収:
				amount_text = "[color=red]ダメージ[/color]の%d%%" % (ability.amount * 100)
				space_length -= 5 # 全角の数だけ追加で減らす
			
			AbilityHealing.AmountType.MAG:
				amount_text = "[color=dodger_blue]MAG[/color]の%d%%" % (ability.amount * 100)
				space_length -= 1 # 全角の数だけ追加で減らす
			
			AbilityHealing.AmountType.現在ゲージ割合:
				amount_text = "現在値の%d%%" % (ability.amount * 100.0)
				space_length -= 4
				
			AbilityHealing.AmountType.最大ゲージ割合:
				amount_text = "最大値の%d%%" % (ability.amount * 100.0)
				space_length -= 4
			
			AbilityHealing.AmountType.現在ゲージ割合_対象:
				amount_text = "現在値の%d%%" % (ability.amount * 100.0)
				space_length -= 4
				
			AbilityHealing.AmountType.最大ゲージ割合_対象:
				amount_text = "最大値の%d%%" % (ability.amount * 100.0)
				space_length -= 4
		
		# ALERT ability.amount_type及びamountによって変わるテキストamount_textの長さによって必要なだけ"0"を入力し、
		# BBcodeのcolorタグで透明を指定することで半角スペースと同様に扱っている。
		# これは膨大な桁数において文字列フォーマットの%を使用すると、
		# 実際に文字が入った場合と空白で補完された場合の幅に、
		# 差異が生じるバグへの応急的な処置である。
		space_length -= len(Global.strip_bbcode(amount_text))
		## 空白の代わりとして用いる"0"の集まり
		var space: String = "[color=transparent]"
		for i in space_length:
			space += "0"
		space += "[/color]"
		
		## 増加量を表示するRichTextLabel
		var amount: RichTextLabel = ability_healing_ui.get_child(0)
		amount.text = "%s%s%s" % [status_text, space, amount_text]
		
		var amount_style: StyleBoxFlat = amount.get_theme_stylebox("normal")
		amount_style.border_color = Color.WHITE
	
	elif ability is AbilityCritical: # ダメージ倍率増加
		gradient.colors = [Color.WHITE, Color.DARK_ORANGE]
		# 不要なラベルを隠す
		for child in get_children():
			if child.get_class() == "Control":
				if child == ability_critical_ui:
					child.show()
				else:
					child.hide()
		
		## 増加量を表示するRichTextLabel
		var amount: RichTextLabel = ability_critical_ui.get_child(0)
		var space_length: int = 10 ## 半角スペースの長さ
		amount_text = "%.2f" % ability.amount
		
		# ALERT この処理についてはmatch文のAbilityHealingの部分を参照
		space_length -= len(Global.strip_bbcode(amount_text))
		## 空白の代わりとして用いる"0"の集まり
		var space: String = "[color=transparent]"
		for i in space_length:
			space += "0"
		space += "[/color]"
		
		amount.text = (
			"[color=dark_orange]ダメージ倍率[/color]:%s%s倍" % 
			[space, amount_text])
		
		var amount_style: StyleBoxFlat = amount.get_theme_stylebox("normal")
		amount_style.border_color = Color.RED
	
	elif ability is AbilityExtra: # 連続攻撃
		var element_color: Color = ability.action.element[0].color
		if ability.action.element[0].id == 0:
			element_color = Color.DIM_GRAY
		
		gradient.colors = [Color.WHITE, element_color]
		# 不要なラベルを隠す
		for child in get_children():
			if child.get_class() == "Control":
				if child == ability_extra_ui:
					child.show()
				else:
					child.hide()
		# 技ボタンを生成する
		var button := Global.ACTION_BUTTON.instantiate() as ActionButton
		button.action = ability.action
		button.position = Vector2(8, 147)
		button.scale = Vector2(0.67, 0.67)
		button.size.x = 497
		button.action_button_up.connect(_on_action_button_up)
		
		ability_extra_ui.add_child(button)
	
	else:
		gradient.colors = [Color.BLACK, Color.BLACK]
	
	fit_name_label_size(ability.bbcode_name)
	name_label.text = "[b]%s[/b]" % ability.bbcode_name
	
	match ability.target:
		Enums.Target.なし:
			target_label.text = "[color=yellow]対象[/color]:　 なし 　"
		
		Enums.Target.近接:
			target_label.text = "[color=yellow]対象[/color]:　 近接 　"
		
		Enums.Target.遠隔:
			target_label.text = "[color=yellow]対象[/color]:　 遠隔 　"
		
		Enums.Target.敵全体:
			target_label.text = "[color=yellow]対象[/color]:　敵全体　"
		
		Enums.Target.自分:
			target_label.text = "[color=yellow]対象[/color]:　 自分 　"
		
		Enums.Target.味方単体:
			target_label.text = "[color=yellow]対象[/color]: 味方単体 "
		
		Enums.Target.味方全体:
			target_label.text = "[color=yellow]対象[/color]: 味方全体 "
		
		Enums.Target.敵味方全体:
			target_label.text = "[color=yellow]対象[/color]:敵味方全体"
		
		_:
			target_label.text = "[center][color=red][b]ERROR[/b][/color][/center]"
	
	chance_label.text = "[color=green]確率[/color]:%3d%%" % ability.chance


func fit_name_label_size(text: String) -> void:
	var font: Font = name_label.get_theme_font("bold_font")
	for i: int in range(80, 0, -1): # 最大サイズ80
		var text_size: Vector2 = font.get_string_size(
			Global.strip_bbcode(text), # bbcodeタグを排除
			HORIZONTAL_ALIGNMENT_CENTER, 
			-1, 
			i)
		if text_size.x <= name_label.size.x - 20 and text_size.y <= name_label.size.y - 20:
			name_label.add_theme_font_size_override("bold_font_size", i)
			break

## [signal ActionButton.action_button_up]を中継し[signal ability_extra_button_up]を発行します
func _on_action_button_up(act: ActionData) -> void:
	ability_extra_button_up.emit(act)
