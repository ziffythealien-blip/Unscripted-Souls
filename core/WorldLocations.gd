extends Node
class_name WorldLocations

var locations: Array = []

func register_location(location: Location):
	if not locations.has(location):
		locations.append(location)

func get_random_location() -> Location:
	if locations.is_empty():
		return null
	return locations.pick_random()

func get_location_by_type(type: String) -> Location:
	for loc in locations:
		if loc.location_type == type:
			return loc
	return get_random_location()
