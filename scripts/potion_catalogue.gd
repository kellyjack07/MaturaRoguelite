extends Resource
class_name PotionCatalogue

@export var definitions: Array[Resource] = []

func get_definition(id: String) -> PotionDefinition:
	for definition: Resource in definitions:
		if definition is PotionDefinition and definition.id == id:
			return definition
	return null
