extends Control

signal close_slideshow()

@onready var lbl_header: Label = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/lblTitle
@onready var pic: TextureRect = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/pic
@onready var txt_main: RichTextLabel = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/ColorRect/MarginContainer/txtMain
@onready var btn_close: Button = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/btnClose
@onready var btn_next: Button = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/HBoxContainer/MarginContainer3/btnNext
@onready var btn_back: Button = $slideContainer/NinePatchRect/MarginContainer/VBoxContainer/HBoxContainer/MarginContainer2/btnBack

@export var slideshow: SlideShow = null

var slides: Array[SlideData] = []
var current_index := 0
var msg_speed: float = 0.3

func show_slideshow(ss: SlideShow):
	if ss:
		ss.is_done = true
		show_slides(ss.slides)
	
func play_slideshow():
	if slideshow:
		slideshow.is_done = true
		show_slides(slideshow.slides)

func _process(delta: float) -> void:
	if visible:
		if txt_main.visible_ratio < 1:
			txt_main.visible_ratio += msg_speed * delta

func show_slides(slide_array: Array[SlideData]):
	slides = slide_array
	current_index = 0
	visible = true
	_update_slide()

func _update_slide():
	var slide = slides[current_index]
	
	if slide == null:
		btn_close.visible = true
		return
	
	lbl_header.text = slide.header
	#pic.texture = slide.image
	txt_main.visible_ratio = 0
	txt_main.text = slide.body_text
	
	#btn_next.text = " Next (" + str(current_index + 1) + "/" + str(slides.size()) + ")  >> "

	# Show/hide buttons
	btn_next.visible = current_index < slides.size() - 1
	btn_back.visible = current_index >= 1
	btn_close.visible = current_index == slides.size() - 1


func _on_btn_close_pressed() -> void:
	close_slideshow.emit()


func _on_btn_next_pressed() -> void:
	current_index += 1
	_update_slide()


func _on_btn_back_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_slide()

func close_popup():
	visible = false
