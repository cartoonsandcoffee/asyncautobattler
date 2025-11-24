extends Resource
class_name SlideData

@export var header: String = ""
@export var image: Texture2D
@export_multiline var body_text: String = "":
	set(value):
		# Sanitize any problematic characters
		body_text = value.strip_edges()