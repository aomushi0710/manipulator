class_name SpeedBar
extends TextureProgressBar

signal gauge_filled

const SPD_GAUGE_MAX_VALUE: float = 5000.0
const SPD_CORRECTION: float = 30.0 ## spdゲージ増加量補正 SPD * spd_correction

var monster: Monster

func _ready() -> void:
	max_value = SPD_GAUGE_MAX_VALUE
	value = 0


func _process(delta: float) -> void:
	if value < SPD_GAUGE_MAX_VALUE: # SPDの値ずつ毎秒増加していき、500まで到達するとコマンドリストを表示
		value += monster.SPD * SPD_CORRECTION * delta
	elif value >= SPD_GAUGE_MAX_VALUE:
		set_process(false)
		gauge_filled.emit()
