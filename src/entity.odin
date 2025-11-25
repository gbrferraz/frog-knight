package frog_knight

import "core:math/linalg"

Entity :: struct {
	pos:             Vec3,
	target_pos:      Vec3i,
	rot:             f32,
	target_rot:      f32,
	is_moving:       bool,
	is_solid:        bool,
	is_pushable:     bool,
	is_interactable: bool,
	gravity:         bool,
	type:            EntityType,
}

EntityType :: enum {
	Wall,
	Box,
	Grass,
	Enemy,
	Door,
}

create_entity :: proc(type: EntityType, pos: Vec3i) -> Entity {
	using entity := Entity {
		pos        = vec3i_to_vec3(pos),
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
		gravity = true
	case .Grass:
		is_solid = true
	case .Enemy:
		is_solid = true
		gravity = true
	case .Door:
		is_solid = true
		is_interactable = true
	}

	return entity
}

update_entity :: proc(using entity: ^Entity, game: ^Game, dt: f32) {
	pos = linalg.lerp(pos, vec3i_to_vec3(target_pos), dt * ENTITY_SPEED)
	distance_to_target := linalg.length(vec3i_to_vec3(target_pos) - pos)

	if distance_to_target < 0.1 {
		pos = vec3i_to_vec3(target_pos)
		is_moving = false
	}

	if gravity {
		pos_below := target_pos - {0, 1, 0}
		if entity_below, _ := get_entity_at_pos(pos_below, game); entity_below == nil {
			// TODO: try_move only takes a relative position, maybe it should take a absolute one?
			// try_move(entity, pos_below, game)

			target_pos = pos_below
		}
	}
}
