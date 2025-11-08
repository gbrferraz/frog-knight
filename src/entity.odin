package frog_knight

import "core:math/linalg"

Entity :: struct {
	pos:             Vector3,
	target_pos:      Vector3,
	rotation:        f32,
	target_rotation: f32,
	is_moving:       bool,
	is_solid:        bool,
	is_pushable:     bool,
	type:            EntityType,
}

EntityType :: enum {
	Wall,
	Box,
	Grass,
	Enemy,
}

create_entity :: proc(type: EntityType, pos: Vector3) -> Entity {
	using entity := Entity {
		pos        = pos,
		target_pos = pos,
		type       = type,
	}

	switch type {
	case .Wall:
		is_solid = true
		is_pushable = false
	case .Box:
		is_solid = true
		is_pushable = true
	case .Grass:
		is_solid = true
	case .Enemy:
		is_solid = true
	}

	return entity
}

update_entity :: proc(using entity: ^Entity, dt: f32) {
	pos = linalg.lerp(pos, target_pos, dt * ENTITY_SPEED)
	distance_to_target := linalg.length(target_pos - pos)

	if distance_to_target < 0.1 {
		pos = target_pos
		is_moving = false
	}
}
