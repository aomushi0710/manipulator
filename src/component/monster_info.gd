class_name BattleMonsterInfo
extends Control

var monster: BattleMonster:
	set(value):
		monster = value
		_ui_update()

@onready var _monster_icon := %MonsterIcon as MonsterIcon
@onready var _expected_pie_chart_label := %ExpectedPieChartLabel as RichTextLabel
@onready var _expected_pie_chart := %ExpectedPieChart as PieChart
@onready var _actual_pie_chart := %ActualPieChart as PieChart
@onready var _action_container := %ActionContainer as VBoxContainer


func _ui_update() -> void:
	_monster_icon.data = monster.data.data
	_monster_icon.form = monster.data.form
	
	_actual_pie_chart.actions = Global.action_to_actiondata(monster.data.data.action)
	_actual_pie_chart.chances = _to_percentages(monster.generated_action_log)
	
	if monster.is_player:
		var float_chances: Array[float]
		float_chances.assign(monster.data.chance)
		_expected_pie_chart.actions = Global.action_to_actiondata(monster.data.data.action)
		_expected_pie_chart.chances = float_chances
	
		var actions := Global.action_to_actiondata(monster.available_action)
		for i in range(4):
			var button := _action_container.get_child(i) as ActionButton
			if actions.size() > i:
				button.action = actions[i]
			else:
				button.action = null
		
		_expected_pie_chart_label.text = "本来の出現確率"
		
		_expected_pie_chart.show()
		_action_container.show()
	else:
		_expected_pie_chart_label.text = "本来の出現確率\n\n相手モンスターの\n出現確率は非公開です\n\n本来の出現確率及び\n現在選択可能な技は\n表示されません"
		
		_expected_pie_chart.hide()
		_action_container.hide()

## 重みづけされた配列を、パーセント表示の配列に変換します
func _to_percentages(weights: Array[int]) -> Array[float]:
	var total_weight: int = 0
	for weight in weights:
		total_weight += weight
	
	var result: Array[float]
	result.resize(weights.size())
	result.fill(0.0)
	for i in weights.size():
		result[i] = float(weights[i]) / total_weight * 100.0
	
	return result
