extends Node
class_name AppearanceSystem

var male_sprites: Array = []
var female_sprites: Array = []

func _ready():
	load_sprites()

func load_sprites():
	male_sprites = load_all("res://sprites/agents/male/")
	female_sprites = load_all("res://sprites/agents/female/")

func load_all(path: String) -> Array:
	var textures = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if not dir.current_is_dir():
				if file.ends_with(".png"):
					textures.append(load(path + file))
			file = dir.get_next()
		dir.list_dir_end()
	return textures

func apply_appearance(agent, sprite: Sprite2D):
	if agent.data.gender == "male":
		if male_sprites.size() > 0:
			sprite.texture = male_sprites[agent.data.sprite_variant % male_sprites.size()]
	else:
		if female_sprites.size() > 0:
			sprite.texture = female_sprites[agent.data.sprite_variant % female_sprites.size()]
