class_name TargetDummy
extends EnemyBase


func cast_action(index: int, targets: Array[BattleUnit]) -> void:
	for t in targets:
		t.apply_damage(1)
		if t.source_node and t.source_node.has_method("on_damaged"):
			t.source_node.on_damaged(1)
