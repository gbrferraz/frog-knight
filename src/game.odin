package frog_knight

import "core:math"
import rl "vendor:raylib"

ENTITY_SPEED :: 20
CAMERA_OFFSET :: Vec3{0, 8, 6}
FONT_SIZE :: 30
BACKGROUND_COLOR :: rl.Color{46, 34, 47, 255}

Vec3 :: [3]f32
Vec2 :: [2]f32
Vec3i :: [3]i32

GameStatus :: enum {
	Playing,
	Lose,
	Win,
}

State :: struct {
	status:   GameStatus,
	player:   Entity,
	entities: []Entity,
}

Game :: struct {
	editor:   Editor,
	status:   GameStatus,
	player:   Entity,
	camera:   rl.Camera,
	entities: [dynamic]Entity,
	history:  [dynamic]State,
	assets:   Assets,
	turn:     TurnState,
}

TurnState :: enum {
	Player,
	Enemy,
}

Assets :: struct {
	player_model: rl.Model,
	box_model:    rl.Model,
	wall_model:   rl.Model,
	grass_model:  rl.Model,
	enemy_model:  rl.Model,
	door_model:   rl.Model,
}

move_player :: proc(using game: ^Game) {
	if player.is_moving || game.status == .Lose {return}

	move_direction: Vec3i

	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
		move_direction.x -= 1
		player.rot = 270
	} else if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
		move_direction.x += 1
		player.rot = 90
	} else if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		move_direction.z -= 1
		player.rot = 180
	} else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		move_direction.z += 1
		player.rot = 0
	}

	if move_direction != 0 {
		state := get_current_state(game)
		append(&game.history, state)

		target_position := player.target_pos + move_direction

		if try_move(&player, move_direction, game) {
			turn = .Enemy
		} else if try_attack(game, target_position) {
			turn = .Enemy
		} else if try_interact(game, target_position) {
			turn = .Enemy
		} else {
			pop(&game.history)
			delete(state.entities)
		}
	}
}

enemies_turn :: proc(using game: ^Game) {
	for &entity in entities {
		if entity.type == .Enemy {
			direction_vector := player.pos - entity.pos
			primary_move, secondary_move: Vec3i

			if rl.Vector3Length(direction_vector) <= 1 {
				// Attack player
				status = .Lose
			} else {
				// Move
				if abs(direction_vector.x) > abs(direction_vector.z) {
					primary_move.x = i32(math.sign(direction_vector.x))
					secondary_move.z = i32(math.sign(direction_vector.z))
				} else {
					primary_move.z = i32(math.sign(direction_vector.z))
					secondary_move.x = i32(math.sign(direction_vector.x))
				}

				if !try_move(&entity, primary_move, game) {
					// try move to other dir
					try_move(&entity, secondary_move, game)
				}
			}
		}
	}
	turn = .Player
}

update_game :: proc(using game: ^Game, dt: f32) {
	if !are_any_entities_moving(game) {
		switch turn {
		case .Player:
			move_player(game)
		case .Enemy:
			enemies_turn(game)
		}
	}

	update_entity(&player, game, dt)

	for &entity in entities {
		update_entity(&entity, game, dt)
	}

	camera_follow(&camera, &player, CAMERA_OFFSET)
}

try_move :: proc(entity: ^Entity, direction: Vec3i, game: ^Game) -> bool {
	if entity.is_moving || direction == 0 {return false}

	next_pos := entity.target_pos + direction
	collided_entity, _ := get_entity_at_pos(next_pos, game)

	if collided_entity != nil {
		if collided_entity.is_pushable {
			next_entity_pos := collided_entity.target_pos + direction
			if next_entity, _ := get_entity_at_pos(next_entity_pos, game);
			   next_entity != nil && next_entity.is_solid {return false}

			collided_entity.target_pos += direction
			collided_entity.is_moving = true

		} else if collided_entity.is_solid {return false}
	}

	entity.target_pos += direction
	entity.is_moving = true
	return true
}

try_attack :: proc(using game: ^Game, pos: Vec3i) -> bool {
	for entity, i in entities {
		if entity.type == .Enemy && entity.target_pos == pos {
			unordered_remove(&entities, i)
			return true
		}
	}

	return false
}

try_interact :: proc(using game: ^Game, pos: Vec3i) -> bool {
	for entity in entities {
		if entity.is_interactable && entity.target_pos == pos {
			if entity.type == .Door {
				game.status = .Win
			}
			return true
		}
	}
	return false
}

get_entity_at_pos :: proc(pos: Vec3i, game: ^Game) -> (entity: ^Entity, index: int) {
	for &entity, i in game.entities {
		if pos == entity.target_pos {
			return &entity, i
		}
	}

	if pos == game.player.target_pos {
		return &game.player, -1
	}

	return nil, -1
}

are_any_entities_moving :: proc(using game: ^Game) -> bool {
	if player.is_moving {
		return true
	}

	for entity in entities {
		if entity.is_moving {
			return true
		}
	}

	return false
}

get_entity_model :: proc(type: EntityType, using game: ^Game) -> ^rl.Model {
	switch type {
	case .Wall:
		return &assets.wall_model
	case .Box:
		return &assets.box_model
	case .Grass:
		return &assets.grass_model
	case .Enemy:
		return &assets.enemy_model
	case .Door:
		return &assets.door_model
	}

	return nil
}

get_current_state :: proc(game: ^Game) -> State {
	entities_slice := make([]Entity, len(game.entities))

	for entity, i in game.entities {
		entities_slice[i] = entity
	}

	current_state := State {
		status   = game.status,
		player   = game.player,
		entities = entities_slice,
	}

	return current_state
}

load_state :: proc(state: State, game: ^Game) {
	game.status = state.status
	game.player = state.player

	clear(&game.entities)

	for entity in state.entities {
		append(&game.entities, entity)
	}
}

undo_move :: proc(game: ^Game) {
	if len(game.history) <= 0 {return}

	undo_state := pop(&game.history)
	load_state(undo_state, game)

	delete(undo_state.entities)
}

camera_follow :: proc(camera: ^rl.Camera, entity: ^Entity, offset: Vec3) {
	camera.position = entity.pos + offset
	camera.target = entity.pos
}
