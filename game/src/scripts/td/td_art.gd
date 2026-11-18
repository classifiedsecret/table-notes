class_name TDArt
extends RefCounted
## Top-down art: our own pieces (td_inn.png, regions in TDArtRects, made by
## tools/make_td_inn_art.py), else side-view inn props, else 0x72 dungeon tiles.

const RECTS := TDArtRects.RECTS

static var _sheet_img: Image
static var _cache := {}


## Our own top-down piece, else a side-view inn prop that also reads from above, else a 0x72 tile.
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D
	if RECTS.has(name):
		# Each piece gets its own texture rather than an atlas region: at fractional camera
		# positions, tiles cut from a shared sheet can sample the transparent gutter between
		# pieces and show a thin black seam. A standalone texture just repeats its own edge.
		if _sheet_img == null:
			_sheet_img = (load("res://assets/sprites/td_inn.png") as Texture2D).get_image()
			_sheet_img.decompress()
		t = ImageTexture.create_from_image(_sheet_img.get_region(Rect2i(RECTS[name])))
	elif InnProps.RECTS.has(name):
		t = InnProps.tex(name)
	else:
		t = Art.region(name)
	_cache[name] = t
	return t


## A standalone copy of a 0x72 dungeon tile (same seam fix as above, for tiled floor and walls).
static func solo(name: String) -> Texture2D:
	var k := "solo:" + name
	if not _cache.has(k):
		var a := Art.region(name) as AtlasTexture
		if a == null:
			_cache[k] = Art.region(name)
		else:
			var img := a.atlas.get_image()
			img.decompress()
			_cache[k] = ImageTexture.create_from_image(img.get_region(Rect2i(a.region)))
	return _cache[k]
