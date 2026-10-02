extends RefCounted
## Pixel-art cat portraits for the cast, looked up by Slouch author or contact id.
## Unknown names ("You", "Operations", channels) have no portrait.

const CatPortrait = preload("res://native/cat_portrait.gd")

const TEXTURES := {
	"maya": preload("res://art/cats/maya.svg"),
	"theo": preload("res://art/cats/theo.svg"),
	"inez": preload("res://art/cats/inez.svg"),
	"morgan": preload("res://art/cats/morgan.svg"),
	"helios": preload("res://art/cats/helios.svg"),
}
## Overlay frames drawn over each base face, `art/cats/<id>-<frame>.svg`. Every
## cat has blink, talk, hover and click; the rest belong to its idle routines.
const FRAMES := {
	"maya": {
		"blink": preload("res://art/cats/maya-blink.svg"),
		"talk": preload("res://art/cats/maya-talk.svg"),
		"hover": preload("res://art/cats/maya-hover.svg"),
		"click": preload("res://art/cats/maya-click.svg"),
		"droop": preload("res://art/cats/maya-droop.svg"),
		"yawn": preload("res://art/cats/maya-yawn.svg"),
		"steam-1": preload("res://art/cats/maya-steam-1.svg"),
		"steam-2": preload("res://art/cats/maya-steam-2.svg"),
	},
	"theo": {
		"blink": preload("res://art/cats/theo-blink.svg"),
		"talk": preload("res://art/cats/theo-talk.svg"),
		"hover": preload("res://art/cats/theo-hover.svg"),
		"click": preload("res://art/cats/theo-click.svg"),
		"ear": preload("res://art/cats/theo-ear.svg"),
		"whisker": preload("res://art/cats/theo-whisker.svg"),
	},
	"inez": {
		"blink": preload("res://art/cats/inez-blink.svg"),
		"talk": preload("res://art/cats/inez-talk.svg"),
		"hover": preload("res://art/cats/inez-hover.svg"),
		"click": preload("res://art/cats/inez-click.svg"),
		"glance-1": preload("res://art/cats/inez-glance-1.svg"),
		"glance-2": preload("res://art/cats/inez-glance-2.svg"),
		"pen-1": preload("res://art/cats/inez-pen-1.svg"),
		"pen-2": preload("res://art/cats/inez-pen-2.svg"),
	},
	"morgan": {
		"blink": preload("res://art/cats/morgan-blink.svg"),
		"talk": preload("res://art/cats/morgan-talk.svg"),
		"hover": preload("res://art/cats/morgan-hover.svg"),
		"click": preload("res://art/cats/morgan-click.svg"),
		"glint-1": preload("res://art/cats/morgan-glint-1.svg"),
		"glint-2": preload("res://art/cats/morgan-glint-2.svg"),
		"glint-3": preload("res://art/cats/morgan-glint-3.svg"),
	},
	"helios": {
		"blink": preload("res://art/cats/helios-blink.svg"),
		"talk": preload("res://art/cats/helios-talk.svg"),
		"hover": preload("res://art/cats/helios-hover.svg"),
		"click": preload("res://art/cats/helios-click.svg"),
		"scan-1": preload("res://art/cats/helios-scan-1.svg"),
		"scan-2": preload("res://art/cats/helios-scan-2.svg"),
		"scan-3": preload("res://art/cats/helios-scan-3.svg"),
		"scan-4": preload("res://art/cats/helios-scan-4.svg"),
		"scan-5": preload("res://art/cats/helios-scan-5.svg"),
		"scan-6": preload("res://art/cats/helios-scan-6.svg"),
		"antenna-1": preload("res://art/cats/helios-antenna-1.svg"),
		"antenna-2": preload("res://art/cats/helios-antenna-2.svg"),
	},
}
## Personality idles, one every 6-10 seconds, taken in turn. Each is a list of
## [frame, seconds] steps; "" shows the plain face for that step.
const IDLES := {
	# Nodding off, a yawn, or the coffee steaming.
	"maya": [
		[["droop", 0.9], ["blink", 0.4], ["droop", 0.7]],
		[["droop", 0.25], ["yawn", 1.1], ["droop", 0.35]],
		[["steam-1", 0.4], ["steam-2", 0.4], ["steam-1", 0.4], ["steam-2", 0.4]],
	],
	# An ear twitch or a whisker flick.
	"theo": [
		[["ear", 0.12], ["", 0.1], ["ear", 0.12]],
		[["whisker", 0.22], ["", 0.14], ["whisker", 0.22]],
	],
	# Side-eye the other way, or tap the checklist with the red pen.
	"inez": [
		[["glance-1", 0.1], ["glance-2", 1.2], ["glance-1", 0.1]],
		[["pen-2", 0.2], ["pen-1", 0.14], ["pen-2", 0.14], ["pen-1", 0.14], ["pen-2", 0.2]],
	],
	# The glasses catch the light.
	"morgan": [
		[["glint-1", 0.07], ["glint-2", 0.07], ["glint-3", 0.22]],
	],
	# A scanline sweeps the visor, or the antenna light pulses.
	"helios": [
		[["scan-1", 0.06], ["scan-2", 0.06], ["scan-3", 0.06], ["scan-4", 0.06], ["scan-5", 0.06], ["scan-6", 0.06]],
		[["antenna-1", 0.18], ["antenna-2", 0.18], ["antenna-1", 0.18], ["antenna-2", 0.18]],
	],
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


## A live cat (see cat_portrait.gd), or an empty Control when there is no portrait.
static func make(person: String, size: int) -> Control:
	var texture := texture_for(person)
	if texture == null:
		var blank := Control.new()
		blank.name = "NoPortrait"
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return blank
	var id := id_for(person)
	var portrait := CatPortrait.new()
	portrait.name = "Portrait"
	portrait.setup(id, texture, FRAMES[id], IDLES[id])
	portrait.custom_minimum_size = Vector2(size, size)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.set_meta("person", id)
	return portrait


## The game paused or resumed. Pass the pausing node: freeing it ends the pause.
static func set_paused(paused: bool, owner: Object = null) -> void:
	CatPortrait.set_paused(paused, owner)


## The player's motion setting. Off, portraits hold still: no blinks, idles,
## mouth flaps or hops. Hover and pokes still change the face.
static func set_motion(enabled: bool) -> void:
	CatPortrait.set_motion(enabled)
