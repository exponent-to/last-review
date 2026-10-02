extends RefCounted
## Pixel-art cat portraits for the cast, looked up by Slouch author or contact id.
## Unknown names ("You", "Operations", channels) have no portrait.

const TEXTURES := {
	"maya": preload("res://art/cats/maya.svg"),
	"theo": preload("res://art/cats/theo.svg"),
	"inez": preload("res://art/cats/inez.svg"),
	"morgan": preload("res://art/cats/morgan.svg"),
	"helios": preload("res://art/cats/helios.svg"),
}
# Contact ids and display names that differ from the portrait id.
const ALIASES := {"manager": "morgan"}


static func id_for(person: String) -> String:
	# "Morgan / Engineering Manager" signs the manager's intro; keep the name only.
	var key := person.get_slice("/", 0).strip_edges().to_lower()
	key = str(ALIASES.get(key, key))
	return key if TEXTURES.has(key) else ""


static func texture_for(person: String) -> Texture2D:
	var id := id_for(person)
	return TEXTURES[id] if not id.is_empty() else null


static func make(person: String, size: int) -> Control:
	var texture := texture_for(person)
	if texture == null:
		var blank := Control.new()
		blank.name = "NoPortrait"
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return blank
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = texture
	portrait.custom_minimum_size = Vector2(size, size)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_meta("person", id_for(person))
	return portrait
