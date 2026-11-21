class_name MapDialog 
extends Control
## マップ上で主に会話の表示に使用されるダイアログ

signal dialog_opened ## ダイアログが開かれる時に発行されるシグナル
signal dialog_closed ## ダイアログが閉じられる時に発行されるシグナル
signal paging
signal button_chosen(id: int) ## ボタンが押された時にIDと同時に発行されるシグナル
signal battle_started ## バトル開始シグナル
signal battle_finished ## バトル終了シグナル

var text_tween: Tween
var text_speed: float = 0.04
var now_id: int ## 現在表示中の[class MapDialogData]の[code]id[/code]
var signboard_id: int ## 現在表示中の[member SignBoard.id]

@onready var text_area := %TextArea as HBoxContainer
@onready var label := %Text as RichTextLabel
@onready var speaker_texture := %SpeakerTexture as TextureRect
@onready var name_plate := %NamePlate as Control
@onready var name_panel := %Panel as TextureRect
@onready var name_label := %Name as RichTextLabel
@onready var name_plate_right := %Right as Polygon2D
@onready var buttons := $Buttons

@onready var _deck_preview := %DeckPreview as ColorRect
@onready var _player_deck_name_label := %PlayerDeckName as RichTextLabel
@onready var _player_deck_monster_container := %PlayerDeckMonsterContainer as HBoxContainer
@onready var _enemy_deck_name_label := %EnemyDeckName as RichTextLabel
@onready var _enemy_deck_monster_container := %EnemyDeckMonsterContainer as HBoxContainer

func _ready() -> void:
	hide()
	_deck_preview.hide() # 消失アニメーションが再生されないようにする

## ダイアログボックスを開き、[signal dialog_opened]シグナルを発行します。
func dialog_open() -> void:
	show()
	dialog_opened.emit()

## ダイアログボックスを閉じ、[signal dialog_closed]シグナルを発行します。
func dialog_close() -> void:
	hide()
	dialog_closed.emit()

## [param datas]から、indexを指定して順番に
##[code]display_dialog()[/code]関数を呼び出していく関数。
## ダイアログの開閉[code]dialog_open()[/code][code]dialog_close()[/code]
##もまとめて行われます。
func dialog_manager(datas: Array[MapDialogData], id: int) -> void:
	dialog_open()
	
	signboard_id = id
	var redirect_id: int = 0 ## 次に表示したい[class MapDialogData]のID
	while redirect_id >= 0: # IDが-1になるまでダイアログ表示を繰り返す
		if datas[redirect_id]:
			redirect_id = await display_dialog(datas[redirect_id])
		else:
			printerr("対応するindexのMapDialogDataが見つかりませんでした。" + 
			"ダイアログ表示を中断します。")
			redirect_id = -1
	
	dialog_close()

## [MapDialogData]型の[param data]を引数として、ダイアログにテキストを表示する関数。
## [br]awaitを付けてページ送りまたはボタンが押されるまで待った後、
##次に表示されるデータのindexを返します
func display_dialog(data: MapDialogData) -> int:
	if visible == false:
		printerr("ダイアログボックスは表示されていません。" + 
		"事前にdialog_open()で表示させてください。")
	
	label.visible_characters = 0
	label.text = data.text
	for child in buttons.get_children():
		child.queue_free()
	
	# 名前テキスト表示処理
	name_label.text = data.name_text
	if data.name_text:
		## 文字数に応じたネームプレートの長さ
		var plate_size: int = name_label.get_content_width() + 200
		# 各種サイズ変更
		name_label.size.x = plate_size
		name_panel.size.x = plate_size
		name_plate_right.position.x = plate_size + name_panel.position.x
		# 色変更
		name_panel.texture.gradient.colors[0] = data.name_color
		
		name_plate.show()
	else:
		name_plate.hide()
	
	# 画像表示処理
	speaker_texture.texture = data.speaker_texture
	if data.speaker_texture:
		text_area.add_theme_constant_override("separation", 55)
	else:
		text_area.add_theme_constant_override("separation", 0)
	
	# ボタン表示処理
	if data.button_text:
		for i in len(data.button_text):
			var button := Global.GAME_BUTTON.instantiate() as GameButton
			if i == 0:
				button.call_deferred("grab_focus")
			button.text = data.button_text[i]
			button.pressed.connect(
				button_chosen.emit.bind(data.button_redirect_id[i]))
			buttons.add_child(button)
		buttons.show()
	else:
		buttons.hide()
	
	if data.deck:
		_player_deck_name_label.text = "あなたのデッキ" 
		if Global.player_deck and Global.player_deck.name:
			_player_deck_name_label.text += ": " + Global.player_deck.name
		
		for monster in Global.player_deck.monster:
			var icon := Global.MONSTER_ICON.instantiate() as MonsterIcon
			_player_deck_monster_container.add_child(icon)
			icon.data = monster.data
		
		Global.enemy_deck = data.deck.duplicate(true) as Deck
		_enemy_deck_name_label.text = "相手　のデッキ"
		if Global.enemy_deck.name:
			_enemy_deck_name_label.text += ": " + Global.enemy_deck.name
		
		for monster in Global.enemy_deck.monster:
			var icon := Global.MONSTER_ICON.instantiate() as MonsterIcon
			_enemy_deck_monster_container.add_child(icon)
			icon.data = monster.data
			
		_deck_preview.show()
		var tween: Tween = _deck_preview.create_tween()
		tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(_deck_preview, "modulate:a", 1.0, 0.5).from(0.0)
	
	elif _deck_preview.visible:
		var tween: Tween = _deck_preview.create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(_deck_preview, "modulate:a", 0.0, 0.5).from(1.0)
		tween.tween_callback(_deck_preview.hide)
		
		for icon in _player_deck_monster_container.get_children() as Array[MonsterIcon]:
			icon.queue_free()
		
		for icon in _enemy_deck_monster_container.get_children() as Array[MonsterIcon]:
			icon.queue_free()
		
	
	text_tween = get_tree().create_tween().bind_node(label)\
	.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	text_tween.tween_property(label, "visible_characters", \
	len(label.text), text_speed * len(label.text))
	
	# ボタン表示があるかどうかによって待つ処理を変える
	if data.button_text:
		## 次に表示したいMapDialogDataのID[br]ボタンがある場合に、動的にIDを変えるための枠
		var redirect_id: int = await button_chosen
		return redirect_id
	elif not data.battle_redirect_id.is_empty():
		await paging
		var is_victory := await _transition_to_battle()
		if is_victory:
			return data.battle_redirect_id[0]
		else:
			return data.battle_redirect_id[1]
	else:
		await paging
		return data.redirect_id

## バトルに移行する関数。[br]勝利すると[code]true[/code]を返します。
func _transition_to_battle() -> bool:
	var result: bool
	
	if signboard_id == 1:
		Global.battle_stage = Global.stage_data[1]
		Global.enemy_deck = load("res://resource/deck/enemy/tutorial.tres").duplicate(true) as Deck
		Global.current_deck = Global.player_deck.duplicate() as Deck
		Global.player_deck = load("res://resource/deck/player/tutorial.tres").duplicate(true) as Deck
		
		battle_started.emit()
		result = bool(await SceneManager.call_sub_scene(
			Global.TUTORIAL_SCENE,
			&"battle_finished",
			SceneManager.fade_out_zoom,
			SceneManager.fade_in_transparent,
			SceneManager.fade_out_transparent,
			SceneManager.fade_in_zoom
		))
		battle_finished.emit()
		
		return result
	else:
		if Global.player_deck.has_empty_slot(): # デッキにモンスターがいなければ敗北として中断
			return false
	
	var battle_scene_path: String = Global.BATTLE_SCENE
	if Global.enemy_deck.is_score_attack:
		battle_scene_path = Global.SCORE_ATTACK_SCENE
	
	Global.battle_stage = Global.stage_data[1]
	
	battle_started.emit()
	result = bool(await SceneManager.call_sub_scene(
		battle_scene_path,
		&"battle_finished",
		SceneManager.fade_out_zoom,
		SceneManager.fade_in_transparent,
		SceneManager.fade_out_transparent,
		SceneManager.fade_in_zoom
	))
	battle_finished.emit()
	
	return result

## Enterキーが押された、またはクリックされた時の処理
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		on_paging()

## Enterキーが押された、またはクリックされた時に[signal paging]シグナルを送る関数
func on_paging() -> void:
	if text_tween and text_tween.is_running():
		text_tween.kill() # tweenがすでに動作しているならアニメーションスキップ
		label.visible_characters = -1 # 全表示
	else:
		paging.emit()
