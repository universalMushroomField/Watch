class_name CardData
extends Resource
## Shared card definition. A deck may contain multiple copies of this resource.

enum Kind { ATTACK, DEFENSE, SPECIAL }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.SPECIAL
## Match a contiguous pattern, ordered from the top toward the bottom.
@export var sequence_cost: Array[CardSequence.Symbol] = []
@export var exhaust_on_play: bool = false
@export var effects: Array[CardEffect] = []
