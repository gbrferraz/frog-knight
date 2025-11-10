package frog_knight

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"

ENTITY_SPEED :: 20
CAMERA_OFFSET :: Vec3{0, 8, 6}
FONT_SIZE :: 30

Vec3 :: [3]f32
Vec2 :: [2]f32
Vec3i :: [3]i32

State :: struct {
	player:   Entity,
	entities: []Entity,
}

Game :: struct {
	editor:   Editor,
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
}

move_player :: proc(using game: ^Game) {
	if player.is_moving {return}

	move_direction: Vec3

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

		target_position := player.pos + move_direction

		if try_move_entity(&player, move_direction, game) {
			turn = .Enemy
		} else if try_attack(game, target_position) {
			turn = .Enemy
		} else {
			pop(&game.history)
			delete(state.entities)
		}
	}
}

enemy_turn :: proc(using game: ^Game) {
	for &entity in entities {
		if entity.type == .Enemy {
			direction_vector := player.pos - entity.pos
			move_vector: Vec3

			if abs(direction_vector.x) > abs(direction_vector.z) {
				move_vector.x = math.sign(direction_vector.x)
			} else {
				move_vector.z = math.sign(direction_vector.z)
			}

			try_move_entity(&entity, move_vector, game)
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
			enemy_turn(game)
		}
	}

	update_entity(&player, dt)

	for &entity in entities {
		update_entity(&entity, dt)
	}

	camera_follow(&camera, &player, CAMERA_OFFSET)
}

try_move_entity :: proc(entity: ^Entity, direction: Vec3, game: ^Game) -> bool {
	if entity.is_moving || direction == 0 {return false}

	next_pos := entity.pos + direction
	collided_entity, _ := get_entity_at_pos(next_pos, game)

	if collided_entity != nil {
		if collided_entity.is_pushable {
			next_entity_pos := collided_entity.pos + direction
			if next_entity, _ := get_entity_at_pos(next_entity_pos, game);
			   next_entity != nil && next_entity.is_solid {return false}

			collided_entity.target_pos += vec3_to_vec3i(direction)
			collided_entity.is_moving = true

		} else if collided_entity.is_solid {return false}
	}

	entity.target_pos += vec3_to_vec3i(direction)
	entity.is_moving = true
	return true
}

try_attack :: proc(using game: ^Game, position: Vec3) -> bool {
	for entity, i in entities {
		if entity.pos == position {
			unordered_remove(&entities, i)
			return true
		}
	}

	return false
}

get_entity_at_pos :: proc(pos: Vec3, game: ^Game) -> (entity: ^Entity, index: int) {
	for &entity, i in game.entities {
		if vec3_to_vec3i(pos) == entity.target_pos {
			return &entity, i
		}
	}

	if vec3_to_vec3i(pos) == game.player.target_pos {
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
	}

	return nil
}

get_current_state :: proc(game: ^Game) -> State {
	entities_slice := make([]Entity, len(game.entities))

	for entity, i in game.entities {
		entities_slice[i] = entity
	}

	save_state := State {
		player   = game.player,
		entities = entities_slice,
	}

	return save_state
}

load_state :: proc(state: State, game: ^Game) {
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

save_game_to_file :: proc(game: ^Game, filepath: string) {
	save_state := get_current_state(game)

	options := json.Marshal_Options {
		use_enum_names = true,
	}

	if data, error := json.marshal(save_state, options); error == nil {
		if os.write_entire_file(filepath, data) {
			fmt.println("Game saved")
		} else {
			fmt.println("Failed to save game")
		}
	} else {
		fmt.println("Failed to marshal game state:", error)
	}
}

load_game_from_file :: proc(game: ^Game, filepath: string) {
	fmt.printf("Attempting to load from: %s\n", filepath)

	if level_data, ok := os.read_entire_file(filepath); ok {
		loaded_state: State

		options := json.Marshal_Options {
			use_enum_names = true,
		}

		if error := json.unmarshal(level_data, &loaded_state); error == nil {
			load_state(loaded_state, game)
			fmt.println("Game loaded successfully!")
		} else {
			fmt.println("Failed to parse JSON:", error)
		}
	} else {
		fmt.println("Failed to read file")
	}
}
