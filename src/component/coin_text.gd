extends RichTextLabel

var tween: Tween
var coin: int:
	set(result):
		coin = result
		text = "[img=50]res://asset/image/coin.PNG[/img] [color=gold]%d[/color]" % coin


func _ready() -> void:
	if SaveManager.save_data:
		coin = SaveManager.save_data.coin

## コイン枚数をアニメーションで変動させる関数 Global.coinとは独立している
func change(n: int) -> void:
	var current_coin: int = coin
	tween = create_tween().bind_node(self)
	tween.tween_property(self, "coin", current_coin + n, 1)
