## [SaveData]及び[Deck]のセーブとロードを行うシングルトン
extends Node

## [code]validate_deck[/code]の実行結果
enum DeckValidationResult {
	UNKNOWN_ERROR = -1, ## 以下のいずれにもあてはまらないエラー
	OK, ## エラーなし
	MIGRATION_REQUIRED, ## サポート対象内ですが補正が必要なデータを読み込もうとしています
	OUTDATED_VERSION_DATA, ## サポート対象外のバージョンのデータを読み込もうとしています
	FUTURE_VERSION_DATA, ## 現在のバージョン以降のデータを読み込もうとしています
	BETA_DATA_IN_MASTER, ## 製品版でβ版データを読み込もうとしています
	MASTER_DATA_IN_BETA, ## β版で製品版データを読み込もうとしています
	INVALID_MONSTER_COUNT, ## 全ての枠にモンスターが登録されていません
	DUPLICATE_MONSTER_ID, ## モンスターがデッキ内で重複しています
}

const SAVE_DATA_PATH: String = "user://savedata.sav"
const SAVE_DATA_PATH_BETA: String = "user://savedata_beta.sav"
const DECK_SAVE_DATA_PATH: String = "user://deck_slot_%02d.res"
const SAVE_KEY: String = "I'm watching you"

const KEY_SCRIPT: StringName = &"@script"
const KEY_RES_PATH: StringName = &"@res_path"

const MIN_SUPPORTED_VERSION: String = "4.4.1" ## このバージョン未満のデータはサポート対象外
const MIGRATION_THRESHOLD_VERSION: String = "4.4.1" ## このバージョン未満のデータはサポート対象内ですがデータを自動修正する必要があります

var save_data: SaveData
var is_new_data: bool = false ## 新規作成されたセーブデータかどうか
var is_save_mode: bool = true ## デッキをセーブするモードかどうか
var can_autosave: bool = true ## オートセーブを行うかどうか


func _ready() -> void:
	load_game()

## [SaveData]をセーブします
func save_game() -> void:
	if not can_autosave:
		return
	
	is_new_data = false
	
	var path: String ## セーブデータファイルパス
	if Global.IS_BETA:
		path = SAVE_DATA_PATH_BETA
	else:
		path = SAVE_DATA_PATH
	
	_save_file(_resource_to_dict(save_data), path)
	save_deck(0)

## [SaveData]をロードします[br]読み込み元のデータが存在しない場合、新規セーブデータを作成します
func load_game() -> void:
	var path: String ## セーブデータファイルパス
	if Global.IS_BETA:
		path = SAVE_DATA_PATH_BETA
	else:
		path = SAVE_DATA_PATH
	
	var dict: Dictionary[StringName, Variant] = await _load_file(path)
	# セーブデータが存在しない時、新規セーブデータ作成
	if dict.is_empty():
		save_data = SaveData.new()
		save_game()
		is_new_data = true
		return
	
	var data: SaveData = _dict_to_resource(SaveData, dict) as SaveData
	# 現在のバージョン以降のデータの場合、オートセーブを切り既存データが上書きされるのを防ぐ
	if not Global.is_version_older(data.version) and data.version != Global.version:
		can_autosave = false
		save_data = SaveData.new()
		
		await DialogManager.set_dialog(preload("res://resource/dialog_data/save_manager/load_from_current_version_onward.tres"), [Global.version])
		await DialogManager.set_dialog(preload("res://resource/dialog_data/save_manager/load_from_current_version_onward_2.tres"))
		DialogManager.hide_dialog()
	
	# TODO 過去のバージョンのデータだった場合、互換性があるかチェックし、
	# データのバージョンを更新する処理を実装する必要あり。
	else:
		save_data = data
	
	Global.player_deck = await load_deck(0)

## [SaveData]を削除します[br]その後新規セーブデータを作成します
func delete_game() -> void:
	var path: String ## セーブデータファイルパス
	if Global.IS_BETA:
		path = SAVE_DATA_PATH_BETA
	else:
		path = SAVE_DATA_PATH
	
	Global.player_deck.clear()
	_delete_file(DECK_SAVE_DATA_PATH % 0)
	_delete_file(path)
	load_game() # セーブデータ削除後に新規セーブデータを作成するため

## 指定したindexのデッキスロットに現在の[Deck]をセーブします
func save_deck(index: int) -> void:
	if Global.player_deck and not Global.player_deck.has_empty_slot() and not Global.player_deck.has_duplicate_monster():
		_save_file(_resource_to_dict(Global.player_deck), DECK_SAVE_DATA_PATH % index)

## 指定したindexのデッキスロットの[Deck]を返します
func load_deck(index: int) -> Deck:
	return _dict_to_resource(Deck, await _load_file(DECK_SAVE_DATA_PATH % index)) as Deck

## 指定したindexのデッキスロットのセーブデータを削除します
func delete_deck(index: int) -> void:
	_delete_file(DECK_SAVE_DATA_PATH % index)

## 引数の[Deck]が有効な状態であるかどうかを検証し、その結果を返します
func validate_deck(deck: Deck) -> DeckValidationResult:
	# 読み込み不可
	if Global.is_version_older(deck.version, MIN_SUPPORTED_VERSION):
		return DeckValidationResult.OUTDATED_VERSION_DATA
	
	if not Global.is_version_older(deck.version) and deck.version != Global.version:
		return DeckValidationResult.FUTURE_VERSION_DATA
	
	if deck.is_beta != Global.IS_BETA:
		if deck.is_beta:
			return DeckValidationResult.BETA_DATA_IN_MASTER
		else:
			return DeckValidationResult.MASTER_DATA_IN_BETA
	
	if deck.has_empty_slot() or deck.monster.size() != 3:
		return DeckValidationResult.INVALID_MONSTER_COUNT
	
	if deck.has_duplicate_monster():
		return DeckValidationResult.DUPLICATE_MONSTER_ID
	
	# 読み込み可能 データの自動修正処理は別途実装すること
	if Global.is_version_older(deck.version, MIGRATION_THRESHOLD_VERSION):
		return DeckValidationResult.MIGRATION_REQUIRED
	
	return DeckValidationResult.OK

## 指定した枚数だけコインを増減させ、自動でセーブを行います
func add_coins(amount: int) -> void:
	save_data.coin += amount
	save_game()

# 以下関数内の処理に生成AIのコードを使用しています
## [Dictionary]に変換されたデータとファイルパスを引数として、データをファイルにセーブします
func _save_file(data: Dictionary[StringName, Variant], path: String) -> void:
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, SAVE_KEY) ## 保存先ファイル
	if file:
		file.store_var(data)
		file.close()
	else:
		var err := FileAccess.get_open_error()
		printerr("セーブ先のファイルが存在しません。%s (エラーコード: %d)" % [error_string(err), err])

# 以下関数内の処理に生成AIのコードを使用しています
## ファイルパスを引数として、ファイルからロードして[Dictionary]を返します
func _load_file(path: String) -> Dictionary[StringName, Variant]:
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SAVE_KEY) ## 読込元ファイル
	if not file:
		var err := FileAccess.get_open_error()
		printerr("セーブファイルが開けません。%s (エラーコード: %d)" % [error_string(err), err])
		return {}
	
	var result: Variant = file.get_var()
	file.close()
	
	if typeof(result) != TYPE_DICTIONARY:
		printerr("セーブデータが破損しています")
		return {}
	
	var typed_result: Dictionary[StringName, Variant] = {} ## 型付き辞書に変換された辞書
	typed_result.assign(result)
	
	print(typed_result)
	if not Global.is_version_older(typed_result.version) and typed_result.version != Global.version:
		print("test")
		await DialogManager.set_dialog(preload("res://resource/dialog_data/save_manager/load_from_current_version_onward_0.tres"), [Global.version, typed_result.version])
		return {}
	
	return typed_result

# 以下関数内の処理に生成AIのコードを使用しています
## ファイルパスを引数として、そのファイルを削除します
func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		
		if err != OK:
			printerr("セーブデータの削除に失敗しました: %s" % err)
		else:
			print("セーブデータを削除しました")
	else:
		printerr("セーブデータが存在しません: %s" % path)

# 以下関数内の処理に生成AIのコードを使用しています
## [Resource]を[Dictionary]に変換します
func _resource_to_dict(res: Resource) -> Dictionary[StringName, Variant]:
	var dict: Dictionary[StringName, Variant] = {}
	var script := res.get_script() as Script
	# 復元時にどのクラスか判別できるよう、スクリプトのパスを記録する
	if script and not script.resource_path.is_empty():
		dict[KEY_SCRIPT] = script.resource_path
		
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"] as int
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (usage & PROPERTY_USAGE_STORAGE):
			var prop_name: StringName = prop["name"] as StringName
			dict[prop_name] = _serialize_value(res.get(prop_name))
			
	return dict

# 以下関数内の処理に生成AIのコードを使用しています
## プロパティの値を[Resource]から[Dictionary]に再帰変換します
func _serialize_value(val: Variant) -> Variant:
	if val is Resource:
		var res: Resource = val
		# スクリプトが付いている場合（自作のカスタムリソース）は中身を辞書化する
		if res.get_script():
			return _resource_to_dict(res)
		# Textureなどのスクリプトを持たない組み込みリソースはファイルパスだけ保存する
		elif not res.resource_path.is_empty():
			return { KEY_RES_PATH: res.resource_path }
		return null
	elif val is Array:
		var arr: Array = val
		var builtin_type: int = arr.get_typed_builtin()
		if builtin_type != TYPE_NIL and builtin_type != TYPE_OBJECT and builtin_type != TYPE_ARRAY and builtin_type != TYPE_DICTIONARY:
			return arr
			
		var size: int = arr.size()
		var serialized_arr: Array = []
		serialized_arr.resize(size)
		for i: int in size:
			serialized_arr[i] = _serialize_value(arr[i])
		return serialized_arr
	elif val is Dictionary:
		var src_dict: Dictionary = val
		var serialized_dict: Dictionary = {}
		for k: Variant in src_dict:
			serialized_dict[k] = _serialize_value(src_dict[k])
		return serialized_dict
		
	return val

# 以下関数内の処理に生成AIのコードを使用しています
## [Dictionary]を[param resource_script]で指定したカスタムリソース型に変換します
## ※内側の辞書も受け取れるよう、第2引数は型なしの[Dictionary]にします
func _dict_to_resource(resource_script: Script, dict: Dictionary) -> Resource:
	var target_script: Script = resource_script
	if dict.has(KEY_SCRIPT):
		var loaded_script := load(dict[KEY_SCRIPT] as String) as Script
		if loaded_script:
			target_script = loaded_script
			
	if not target_script:
		return null
		
	var res := target_script.new() as Resource
	if not res:
		return null
		
	for key: Variant in dict:
		var prop_name := StringName(key)
		if prop_name == KEY_SCRIPT or prop_name == KEY_RES_PATH:
			continue
			
		var current_val: Variant = res.get(prop_name)
		var raw_val: Variant = dict[key]
		
		if current_val is Array and raw_val is Array:
			var target_arr: Array = current_val
			var elem_script := target_arr.get_typed_script() as Script
			var deserialized_arr: Array = _deserialize_array(raw_val, elem_script)
			target_arr.assign(deserialized_arr)
			res.set(prop_name, target_arr)
		elif current_val is Dictionary and raw_val is Dictionary:
			var target_dict: Dictionary = current_val
			var deserialized_val: Variant = _deserialize_value(raw_val)
			if deserialized_val is Dictionary:
				target_dict.assign(deserialized_val)
				res.set(prop_name, target_dict)
		else:
			res.set(prop_name, _deserialize_value(raw_val))
			
	return res

# 以下関数内の処理に生成AIのコードを使用しています
## 保存された値を元の型に再帰復元します
func _deserialize_value(val: Variant, fallback_script: Script = null) -> Variant:
	if val is Dictionary:
		var dict: Dictionary = val
		# Textureなどの外部アセットをパスから読み込む
		if dict.has(KEY_RES_PATH):
			var res_path: String = dict[KEY_RES_PATH] as String
			if ResourceLoader.exists(res_path):
				return load(res_path)
			return null
		# カスタムリソースを記録されたスクリプトパスから復元する
		elif dict.has(KEY_SCRIPT):
			var script_path: String = dict[KEY_SCRIPT] as String
			var script := load(script_path) as Script
			if script:
				return _dict_to_resource(script, dict)
			return null
		elif fallback_script:
			return _dict_to_resource(fallback_script, dict)
			
		# 通常のDictionaryの復元
		var deserialized_dict: Dictionary = {}
		for k: Variant in dict:
			deserialized_dict[k] = _deserialize_value(dict[k])
		return deserialized_dict
		
	elif val is Array:
		return _deserialize_array(val)
		
	return val

# 以下関数内の処理に生成AIのコードを使用しています
## 配列内の要素を再帰的に復元します
func _deserialize_array(src_arr: Array, elem_script: Script = null) -> Array:
	var size: int = src_arr.size()
	var deserialized_arr: Array = []
	deserialized_arr.resize(size)
	for i: int in size:
		deserialized_arr[i] = _deserialize_value(src_arr[i], elem_script)
	return deserialized_arr
