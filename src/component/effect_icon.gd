class_name EffectIconButton
extends TextureButton

@onready var turn_label := %Turn as RichTextLabel
@onready var parent: BattleMonster = $"../.."

var effect: MonsterEffect

func _ready() -> void:
	turn_label.text = "[b][i]%d[/i][/b]" % effect.turn
	
	if effect.effect is AbilityEffect: # TODO 未定
		texture_normal = preload("res://asset/image/null.PNG")
	elif effect.effect is AbilityBuff:
		texture_normal = preload("res://asset/image/element/バフ技.PNG")
	elif effect.effect is AbilityDebuff:
		texture_normal = preload("res://asset/image/element/デバフ技.PNG")
	else:
		texture_normal = preload("res://asset/image/null.PNG")
	
	effect.turn_changed.connect(_on_turn_changed)
	effect.deleted.connect(_on_monster_effect_deleted)

## ボタンが押された時、エフェクト説明文を出す関数
func _on_button_up() -> void:
	await DialogManager.set_text_dialog(preload("res://resource/dialog_data/common/dynamic.tres"), [effect.effect.name, effect.description])
	DialogManager.hide_dialog()

## [member MonsterEffect.turn]が変更された時、UIの表示を更新します
func _on_turn_changed() -> void:
	turn_label.text = "[b][i]%d[/i][/b]" % effect.turn

## [MonsterEffect]が削除された時、[member BattleMonster.effect_list]から[MonsterEffect]を削除しつつ、UIを削除します。
func _on_monster_effect_deleted() -> void:
	parent.effect_list.erase(effect)
	queue_free()
