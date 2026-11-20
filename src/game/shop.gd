extends Control

const ITEM_SCENE = preload("res://scene/component/shop_item.tscn")

var coin_tween: Tween
var selected_item: ShopItem

@onready var item_container := %Item as HBoxContainer
@onready var buy_button := %Buy as Button
@onready var coin_label := %Coin as RichTextLabel
@onready var preview_texture := %PreviewTexture as Sprite2D
@onready var current_level_description_label := %CurrentLevel/Text as RichTextLabel
@onready var next_level_description_label := %NextLevel/Text as RichTextLabel

func _ready() -> void:
	for i in range(1, len(Global.item_data) + 1): # 商品表示
		var shop_item := ITEM_SCENE.instantiate() as ShopItem
		shop_item.item = Global.item_data[i]
		shop_item.button_up.connect(item_button_up)
		item_container.add_child(shop_item)
	update(0)

## 所持コイン数やショップのラインナップを更新する関数
func update(paid: int) -> void:
	for shop_item in item_container.get_children():
		shop_item.update()
	
	if selected_item == null: # 選ばれているアイテムがなければ
		buy_button.disabled = true
		current_level_description_label.text = "[center][b]アイテム名 Lv.0[/b][/center][font_size=20]\n\n[/font_size][font_size=40]現在所持しているアイテムの\n能力が表示されます！[/font_size]"
		next_level_description_label.text = "[center][b]アイテム名 Lv.0[/b][/center][font_size=20]\n\n[/font_size][font_size=40]レベルアップ後の能力が\n表示されます！[/font_size]"
	else: # あれば続けて表示する
		item_button_up(selected_item)
	
	coin_label.change(paid)

## アイテムが選ばれた時、説明文を表示する関数
func item_button_up(shop_item: ShopItem) -> void:
	selected_item = shop_item
	var item: Item = selected_item.item
	
	var level: int = item.get_level()
	var description: String
	preview_texture.texture = item.image
	if item.id not in SaveManager.save_data.item: # 未所持の時
		buy_button.disabled = false
		current_level_description_label.text = "[center]未所持[/center]"
		description = item.get_description(level + 1)
		next_level_description_label.text = "[center][b]%s Lv.%d[/b][/center][font_size=20]\n\n[/font_size][font_size=40]%s[/font_size]" % [item.name, level + 1, description]
	else:
		if level < item.max_level: # 所持しているが最大レベルでない時
			buy_button.disabled = false
			description = item.get_description(level)
			current_level_description_label.text = "[center][b]%s Lv.%d[/b][/center][font_size=20]\n\n[/font_size][font_size=40]%s[/font_size]" % [item.name, level, description]
			description = item.get_description(level + 1)
			next_level_description_label.text = "[center][b]%s Lv.%d[/b][/center][font_size=20]\n\n[/font_size][font_size=40]%s[/font_size]" % [item.name, level + 1, description]
		else: # 最大レベルに達している時
			buy_button.disabled = true
			description = item.get_description(item.max_level)
			current_level_description_label.text = "[center][b]%s Lv.%d[/b][/center][font_size=20]\n\n[/font_size][font_size=40]%s[/font_size]" % [item.name, item.max_level, description]
			next_level_description_label.text = \
			"[center]レベル上限に達しています！[/center]"


func _on_back_button_up() -> void:
	SceneManager.change_scene(
		Global.MAP_SCENE,
		SceneManager.fade_out_transparent,
		SceneManager.fade_in_zoom
	)


func _on_buy_button_up() -> void:
	if SaveManager.save_data.coin < selected_item.price:
		await DialogManager.set_text_dialog(preload("res://resource/dialog_data/shop/coin_shortage.tres"))
		DialogManager.hide_dialog()
	else:
		var selected_index: int = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/shop/purchase_item_1.tres"), [selected_item.item.name, selected_item.item.get_level() + 1])
		if selected_index == 0:
			# アイテム情報もセーブするので、ここではセーブしない
			SaveManager.save_data.coin -= selected_item.price
			
			if selected_item.item.id not in SaveManager.save_data.item: # 未所持の時
				SaveManager.save_data.item[selected_item.item.id] = 1
			else:
				SaveManager.save_data.item[selected_item.item.id] += 1
			
			SaveManager.save_game()
			update(-selected_item.price)
			
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/shop/purchase_item_2.tres"), [selected_item.item.name, selected_item.item.get_level()])
		DialogManager.hide_dialog()
