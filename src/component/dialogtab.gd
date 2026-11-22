extends TabContainer

@export var next_page_arrow: RichTextLabel
@onready var sign_pos = next_page_arrow.position
var tween: Tween
var arrow_tween: Tween
var dialog_expand_tween: Tween
var text_speed: float = 0.04 ## テキストアニメーションの1文字あたりの再生速度
var now_flavor_text: BattlelogData ## 現在表示中のflavor_textを保持
var global_flavor_text: Array[BattlelogData] ## 全てのステージで表示されるフレーバーテキスト
var global_flavor_text_weight: Array[int] ## 全てのステージで表示されるフレーバーテキストの重みづけテーブル
var stage_flavor_text: Array[BattlelogData] ## ステージ固定のフレーバーテキスト
var stage_flavor_text_weight: Array[int] ## ステージ固定フレーバーテキストの重みづけテーブル

## それぞれのtabに対応する[BattlelogData]を格納する辞書
var text_data: Dictionary[BattlelogData.Tab, BattlelogData] = {
	BattlelogData.Tab.MAIN: null,
	BattlelogData.Tab.STATUS: null,
	BattlelogData.Tab.BATTLE_LOG: null,
}

var image_list := [[null], [null], [null]] ## それぞれのtabの位置に画像を保存する配列
var current_page: int = 0 ## 現在のページ
var has_next_page: bool = false:
	set(value):
		if has_next_page != value:
			has_next_page = value
			_next_arrow_animation(value)

signal paging ## ダイアログボックスのテキストをメッセージ送りした時に発行されるシグナル


func _ready() -> void:
	global_flavor_text = [
		BattlelogData.new(
			["これは...なんとも作りが粗い。\nテストプレイの気配がする。"], false
		)
	]
	global_flavor_text_weight = [1]
	text_data[BattlelogData.Tab.MAIN] = BattlelogData.new()
	text_data[BattlelogData.Tab.STATUS] = BattlelogData.new(
		["Status ボタンから味方と相手の\nステータスを確認できます！"], false
	)
	text_data[BattlelogData.Tab.BATTLE_LOG] = BattlelogData.new()
	current_tab = 0
	_on_tab_changed(current_tab) # 初期値タブのテキストをアニメーション

## ダイアログボックスに表示するフレーバーテキストの専用setter
func flavor_text_setter() -> void:
	text_setter(now_flavor_text)

## ダイアログボックスに表示するテキストのsetter[br]
## 
func text_setter(data: BattlelogData) -> void:
	if tween:
		tween.kill()
	
	# should_waitがfalseの場合でも、次のページが存在していれば、
	# _on_tab_changed関数内で自動的にtrueに変更されます。
	has_next_page = data.should_wait
	text_data[data.tab] = data
	_on_tab_changed(data.tab)
	
	# 最後のページがメッセージ送りされてからこの関数の処理を終える
	# これによって、この関数をawaitで待ちながら呼んだ元の関数を再開させることができる
	if has_next_page == true:
		await paging

## タブが切り替え、ページ数を0にリセットしてtext_animationを呼ぶ関数
func _on_tab_changed(tab: BattlelogData.Tab) -> void:
	if tab != BattlelogData.Tab.BATTLE_LOG:
		var label: RichTextLabel ## 現在表示中のタブのラベル
		for child in get_child(tab).get_children():
			if child is RichTextLabel:
				label = child
				break
		
		label.text = "" # 一旦削除してからアニメーション
		if $"../../".enemy_monster != null: # 元に戻す
			$"../../".enemy_monster.effect_container.mouse_filter = MouseFilter.MOUSE_FILTER_STOP
		
		if size.y != 270: # 拡大されていた時に戻すアニメーション
			var duration = (size.y - 270) / 1448 # 現在サイズからアニメーション秒数を逆算(最大0.5)
			
			dialog_expand_tween = (
				self.create_tween()
				.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				.set_parallel()
			)
			dialog_expand_tween.tween_property(
				self, "size:y", 270, duration
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
			dialog_expand_tween.tween_property(
				self, "position:y", 800, duration
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
			dialog_expand_tween.tween_property(
				next_page_arrow, "modulate:a", 1, duration
			)
			
			await dialog_expand_tween.finished
		
		current_tab = tab
		current_page = 0
		text_animation(tab, current_page)
	
	else: # バトルログ表示処理
		get_child(tab).get_child(0).text = ""
		current_tab = tab
		
		# ALERT バトルログが拡大された時、裏にいるモンスターにマウスカーソルが
		# 反応してしまうため、応急処置としてモンスター側のマウスカーソルをデフォルトに
		for child in get_children():
			child.mouse_default_cursor_shape = Control.CURSOR_ARROW
			for c in child.get_children():
				c.mouse_default_cursor_shape = Control.CURSOR_ARROW
		
		dialog_expand_tween = (
			self.create_tween()
			.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			.set_parallel()
		)
		dialog_expand_tween.tween_property(
			self, "size:y", 994, 0.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		dialog_expand_tween.tween_property(
			self, "position:y", 76, 0.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		dialog_expand_tween.tween_property(
			next_page_arrow, "modulate:a", 0, 0.5
		)
		
		await dialog_expand_tween.finished
		
		# スクロールの邪魔にならないように一旦操作受付を止める
		if $"../../".enemy_monster != null: 
			$"../../".enemy_monster.effect_container.mouse_filter = (
				MouseFilter.MOUSE_FILTER_IGNORE
			)
		
		text_animation(tab, -1) # ページはない

## _inputもしくはlabel_gui_inputから、次のページを指定してtext_animationを呼ぶ関数
func text_change_next() -> void:
	# tweenがすでに動作しているならアニメーションスキップ
	if tween and tween.is_running():
		tween.kill()
		## 現在表示中のタブにおける[RichTextLabel]ノード
		var label = get_child(current_tab).get_node("Text")
		label.visible_characters = len(label.text) # テキストを全表示
	else: # まだ次のページが存在する場合
		if len(text_data[current_tab].text) - 1 > current_page:
			current_page += 1
			text_animation(current_tab, current_page)
		else: # 最後のページの時、処理を進める
			_next_arrow_animation(false)
			paging.emit()

## Enterキーが押された時、ページ変更ボタンか押された時と同様に振る舞う
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		text_change_next()

## labelの範囲内で左クリックされた時、ページ変更ボタンか押された時と同様に振る舞う
func label_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton and 
		event.pressed and 
		event.button_index == MOUSE_BUTTON_LEFT
	):
		text_change_next()

## タブのindex、ページ数を引数としてテキストをアニメーション表示させる関数
func text_animation(tab: BattlelogData.Tab, page: int) -> void:
	if tween: # tweenがすでに動作しているなら停止
		tween.kill()
	
	var container: HBoxContainer = get_child(tab) ## タブのHboxContainer
	var label: RichTextLabel ## タブのRichTextLabel
	for child in container.get_children():
		if child is RichTextLabel: # ラベルなら取得
			label = child
		else: # それ以外消す　初期化
			child.queue_free() 
	
	label.text = text_data[tab].text[page]
	
	if tab == BattlelogData.Tab.BATTLE_LOG:
		label.get_v_scroll_bar().value = label.get_v_scroll_bar().max_value
		return
	
	label.visible_characters = 0
	if text_data[tab].image.size() > page and text_data[tab].image[page] != null: # 画像が存在する時
		container.alignment = BoxContainer.ALIGNMENT_BEGIN
		var image = text_data[tab].image[page] ## 挿入される画像
		image.custom_minimum_size = image.size
		label.custom_minimum_size.x = 930 - image.size.x
		container.add_child(image)
		container.move_child(image, 0)
	else:
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		label.custom_minimum_size.x = 930
	
	tween = ( # テキストアニメーション再生
		label.create_tween()
		.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	)
	tween.tween_property(
		label,
		"visible_characters",
		len(label.text),
		text_speed * len(label.text)
	)
	
	# 最後のページではない時
	if len(text_data[current_tab].text) - 1 > current_page:
		has_next_page = true


func _next_arrow_animation(has_next: bool) -> void:
	if arrow_tween and arrow_tween.is_running():
		arrow_tween.kill()
	
	var cursor: CursorShape
	var color: Color
	if has_next:
		cursor = Control.CURSOR_POINTING_HAND
		color = Color.WHITE
	else:
		cursor = Control.CURSOR_ARROW
		color = Color.DIM_GRAY
	
	for child in get_children():
		child.mouse_default_cursor_shape = cursor
		for c in child.get_children():
			c.mouse_default_cursor_shape = cursor
	next_page_arrow.modulate = color
	
	arrow_tween = ( # 矢印アニメーション再生
		next_page_arrow.create_tween()
		.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	)
	
	if has_next:
		next_page_arrow.position.y = sign_pos.y
		arrow_tween.set_loops()
		arrow_tween.tween_property(
			next_page_arrow, "position:y", sign_pos.y - 25, 0.5
		)
		arrow_tween.tween_property(
			next_page_arrow, "position:y", sign_pos.y, 0.3
		).set_trans(Tween.TRANS_EXPO)
		arrow_tween.tween_interval(0.5)
	else:
		arrow_tween.tween_property(
			next_page_arrow, "position:y", sign_pos.y, 0.5
		).set_trans(Tween.TRANS_EXPO)

## バトル終了時の処理
func battle_finished() -> void:
	if tween and tween.is_running(): # ボタン点滅アニメーション停止
		tween.stop()
	if arrow_tween and arrow_tween.is_running():
		arrow_tween.stop()
