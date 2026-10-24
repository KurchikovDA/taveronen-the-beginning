# plugin.gd
#
# Editor plugin: while editing any scene in Godot (no need to press
# Play), continuously fits every Button, Label, and BBCode
# RichTextLabel in the currently open scene to their own size - live,
# using the exact same rules as the runtime autoload (see
# res://scripts/autoload/auto_fit_runtime.gd and
# res://scripts/text_fit/text_fitter.gd), so what you see here
# always matches what the game will actually look like.
@tool
extends EditorPlugin

func _process(_delta: float) -> void:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	_scan(root)

func _scan(node: Node) -> void:
	_try_fit(node)
	for child in node.get_children():
		_scan(child)

func _try_fit(node: Node) -> void:
	if node is Button or node is Label:
		TextFitter.fit_button_or_label(node)
	elif node is RichTextLabel and node.bbcode_enabled:
		TextFitter.fit_rich_text(node)
