class_name PortalDialog
extends PanelContainer
## Modal message for the stage-1 portal stub.
## It has exactly one real action - close - and does not pretend travel exists.

signal closed

@onready var _title: Label = $Margin/VBox/Title
@onready var _headline: Label = $Margin/VBox/Headline
@onready var _body: Label = $Margin/VBox/Body
@onready var _close_button: Button = $Margin/VBox/CloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)


func open(portal: Portal) -> void:
	_title.text = "Портал «%s»" % portal.portal_name
	_headline.text = portal.status_headline
	_body.text = portal.status_text
	show()
	_close_button.grab_focus()


func get_headline_text() -> String:
	return _headline.text


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputActions.INTERACT) or event.is_action_pressed(InputActions.RELEASE_MOUSE):
		get_viewport().set_input_as_handled()
		close()
