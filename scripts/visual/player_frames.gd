class_name PlayerFrames
extends RefCounted

# Animations du reveur a partir de assets/sprites/player/sheet.png (tools/gen_pixel_art.py) :
# 0 repos, 1 clignement, 2-4 marche.

const SHEET := preload("res://assets/sprites/player/sheet.png")
const FRAME_COUNT := 5
const SHADOW_Y := 24.0

static var _frames: SpriteFrames

static func make() -> SpriteFrames:
	if _frames != null:
		return _frames
	_frames = SpriteFrames.new()
	_frames.remove_animation("default")
	_frames.add_animation("idle")
	_frames.set_animation_speed("idle", 5.0)
	_frames.add_frame("idle", _frame(0), 12.0)
	_frames.add_frame("idle", _frame(1), 1.0)
	_frames.add_animation("walk")
	_frames.set_animation_speed("walk", 8.0)
	for i in [2, 3, 4, 3]:
		_frames.add_frame("walk", _frame(i))
	return _frames

static func _frame(index: int) -> AtlasTexture:
	var w := SHEET.get_width() / FRAME_COUNT
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(index * w, 0, w, SHEET.get_height())
	return atlas

static func animate(sprite: AnimatedSprite2D, moving: bool) -> void:
	var anim := "walk" if moving else "idle"
	if sprite.animation != anim:
		sprite.play(anim)
