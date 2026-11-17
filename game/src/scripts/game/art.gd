class_name Art
## Shared art helpers: atlas regions, sprite strips, fonts and the hit-flash shader.

const ATLAS := preload("res://assets/sprites/0x72_atlas.png")
const FONT := preload("res://assets/fonts/kenney_mini_square.ttf")
const FONT_BIG := preload("res://assets/fonts/kenney_pixel.ttf")

const FLASH_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Optional 1px outline so a sprite reads against busy backgrounds. frame_w keeps
// the samples inside the current frame of a horizontal strip (0 = no outline).
uniform vec4 outline_color : source_color = vec4(0.0);
uniform float frame_w = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (c.a < 0.1 && frame_w > 0.0 && outline_color.a > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float lx = mod(floor(UV.x / px.x), frame_w);
		float a = 0.0;
		if (lx > 0.5) a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		if (lx < frame_w - 1.5) a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		if (a > 0.5) {
			COLOR = vec4(outline_color.rgb, outline_color.a * COLOR.a);
		} else {
			COLOR = c;
		}
	} else {
		COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
	}
}
"""

static var _regions := {}
static var _shader: Shader
static var _fonts_ready := false


static func setup_fonts() -> void:
	if _fonts_ready:
		return
	_fonts_ready = true
	for f: FontFile in [FONT, FONT_BIG]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


static func region(name: String) -> AtlasTexture:
	if not _regions.has(name):
		var t := AtlasTexture.new()
		t.atlas = ATLAS
		t.region = AtlasRects.RECTS[name]
		_regions[name] = t
	return _regions[name]


## anims: {name: [first_frame, frame_count, fps, loop]}
static func strip_frames(tex: Texture2D, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim_name: String in anims:
		var a: Array = anims[anim_name]
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, a[2])
		sf.set_animation_loop(anim_name, a[3])
		for i in int(a[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((int(a[0]) + i) * fw, 0, fw, fh)
			sf.add_frame(anim_name, at)
	return sf


static func flash_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m


static func label_settings(size: int, color: Color, outline := 2, big := false) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = FONT_BIG if big else FONT
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0.05, 0.04, 0.07)
	return s
