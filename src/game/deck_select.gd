extends Control

const MAX_SLOT_COUNT: int = 10

@onready var player_deck_slot := %PlayerDeckSlot as DeckSlot
@onready var deck_slot_container := %DeckSlotContainer as VBoxContainer

var all_decks: Array[Deck]

func _ready() -> void:
	# 現在のデッキスロットのみUIを変化
	if not Global.player_deck or not Global.player_deck.has_valid_slot():
		player_deck_slot.deck_name_label.hide()
		player_deck_slot.version_label.hide()
	else:
		player_deck_slot.deck = Global.player_deck
		player_deck_slot.deck_name_label.text = Global.player_deck.name
		player_deck_slot.version_label.text = "[i]ver." + Global.player_deck.version + "[/i]"
		if Global.player_deck.is_beta:
			player_deck_slot.version_label.text += "(β)"
		
		player_deck_slot.deck_name_label.show()
		player_deck_slot.version_label.show()
	
	all_decks.resize(MAX_SLOT_COUNT)
	
	for i in range(1, MAX_SLOT_COUNT):
		var deck_slot := preload("res://scene/component/deck_slot.tscn").instantiate() as DeckSlot
		deck_slot.slot_index = i
		deck_slot_container.add_child(deck_slot)
		deck_slot.save_button.button_up.connect(_on_save_button_up.bind(i))
		deck_slot.load_button.button_up.connect(_on_load_button_up.bind(i))
		deck_slot.delete_button.button_up.connect(_on_delete_button_up.bind(i))
		
		_update_ui(deck_slot)


func _update_ui(deck_slot: DeckSlot) -> void:
	var deck: Deck = SaveManager.load_deck(deck_slot.slot_index)
	all_decks[deck_slot.slot_index] = deck
	deck_slot.deck = deck


func _on_back_button_up() -> void:
	SceneManager.change_scene(Global.SELECT_SCENE)


func _on_save_button_up(index: int) -> void:
	if Global.player_deck.has_empty_slot():
		await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/save_with_empty_slot.tres"))
		DialogManager.hide_dialog()
		return
	
	SaveManager.save_deck(index)
	_update_ui(deck_slot_container.get_child(index - 1))
	
	await DialogManager.set_text_dialog(preload("res://resource/dialog_data/common/save_complete.tres"))
	DialogManager.hide_dialog()


func _on_load_button_up(index: int) -> void:
	match SaveManager.validate_deck(all_decks[index]):
		SaveManager.DeckValidationResult.OUTDATED_VERSION_DATA:
			await  DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_outdated_version_data.tres"), [SaveManager.MIN_SUPPORTED_VERSION])
		
		SaveManager.DeckValidationResult.FUTURE_VERSION_DATA:
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_current_version_onward.tres"), [Global.version])
		
		SaveManager.DeckValidationResult.BETA_DATA_IN_MASTER:
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_beta_in_master.tres"))
		
		SaveManager.DeckValidationResult.MASTER_DATA_IN_BETA:
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_master_in_beta.tres"))
		
		SaveManager.DeckValidationResult.INVALID_MONSTER_COUNT:
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_invalid_monster_count_data.tres"))
		
		SaveManager.DeckValidationResult.DUPLICATE_MONSTER_ID:
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/save_manager/load_from_duplicate_monster_id_data.tres"))
		
		SaveManager.DeckValidationResult.OK:
			Global.player_deck = all_decks[index]
			_update_ui(player_deck_slot)
			await DialogManager.set_text_dialog(preload("res://resource/dialog_data/common/load_complete.tres"))
	
	DialogManager.hide_dialog()


func _on_delete_button_up(index: int) -> void:
	var selected_index: int = await DialogManager.set_text_dialog(preload("res://resource/dialog_data/deck_select/delete_deck_slot_1.tres"), [index])
	if selected_index == 0:
		SaveManager.delete_deck(index)
		_update_ui(deck_slot_container.get_child(index - 1))
		await DialogManager.set_text_dialog(preload("res://resource/dialog_data/deck_select/delete_deck_slot_2.tres"), [index])
	
	DialogManager.hide_dialog()
