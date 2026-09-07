extends Node

# V30 retires the old hand-built V23 waterfront overlay.
# The detailed OSM/DEM world, V30 facade/road pass and functional terminals now own the coastline.
# Keeping the legacy primitive overlay caused duplicate/interpenetrating structures and also carried
# a stale Godot 4.4 type-inference parse error. Older release branches keep the original script.

func _ready() -> void:
	pass
