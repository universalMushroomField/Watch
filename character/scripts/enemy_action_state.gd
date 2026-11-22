## 敌人的单回合行动及其后继状态。
class_name EnemyActionState
extends Resource

@export var intent_text: String
@export var effects: Array[Effect] = []
@export var next_state: int = 0
