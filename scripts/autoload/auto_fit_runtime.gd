extends Node

func _ready() -> void:
	_scan(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	_try_fit(node)
	if node is Control and not node.resized.is_connected(_on_control_resized):
		node.resized.connect(_on_control_resized.bind(node))

func _on_control_resized(node: Control) -> void:
	_try_fit(node)

# Public entry point: re-checks every Button/Label/RichTextLabel in the
# whole tree. Call this after anything that can change displayed text
# without resizing the control - most importantly, right after
# switching the game's language with TranslationServer.set_locale(),
# since translated text is usually a different length than the
# original and needs a different font size to fit.
func refit_all() -> void:
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	_try_fit(node)
	for child in node.get_children():
		_scan(child)

func _try_fit(node: Node) -> void:
	if node is Button or node is Label:
		TextFitter.fit_button_or_label(node)
	elif node is RichTextLabel and node.bbcode_enabled:
		TextFitter.fit_rich_text(node)
