package frog_knight

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

Vector3 :: [3]f32
Vector2 :: [2]f32

ENTITY_SPEED :: 20
CAMERA_OFFSET :: Vector3{0, 8, 6}
FONT_SIZE :: 30

Entity :: struct {
	pos:             Vector3,
	target_pos:      Vector3,
	rotation:        f32,
	target_rotation: f32,
	is_moving:       bool,
	is_solid:        bool,
	is_pushable:     bool,
	model:           ^rl.Model,
}

EntityType :: enum {
	Wall,
	Box,
	Enemy,
}

State :: struct {
	player:   Entity,
	entities: []Entity,
}

Editor :: struct {
	active:         bool,
	current_entity: EntityType,
	preview_pos:    Vector3,
	cursor_busy:    bool,
}

Game :: struct {
	editor:       Editor,
	player:       Entity,
	camera:       rl.Camera,
	entities:     [dynamic]Entity,
	history:      [dynamic]State,
	player_model: rl.Model,
	box_model:    rl.Model,
	wall_model:   rl.Model,
}

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "Frog Knight")
	rl.SetTargetFPS(60)

	font := rl.LoadFontEx("../res/fonts/AtkinsonHyperlegibleNext-Regular.ttf", FONT_SIZE, nil, 0)
	rl.GuiSetFont(font)
	rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), FONT_SIZE)

	game := Game {
		camera = {up = {0, 1, 0}, fovy = 45, projection = .PERSPECTIVE},
		player_model = rl.LoadModel("../res/models/player.glb"),
		box_model = rl.LoadModel("../res/models/box.glb"),
		wall_model = rl.LoadModel("../res/models/wall.glb"),
	}

	animation_frame: i32

	animation_count: i32
	player_animations := rl.LoadModelAnimations("../res/models/player.glb", &animation_count)


	material_texture := rl.LoadTexture("../res/resurrect-64.png")

	rl.SetTextureFilter(material_texture, .BILINEAR)

	rl.SetMaterialTexture(&game.box_model.materials[1], .ALBEDO, material_texture)
	rl.SetMaterialTexture(&game.wall_model.materials[1], .ALBEDO, material_texture)
	rl.SetMaterialTexture(&game.player_model.materials[1], .ALBEDO, material_texture)

	box := Entity {
		pos         = {2, 0, 2},
		is_solid    = true,
		is_pushable = true,
		model       = &game.box_model,
	}

	wall := Entity {
		pos         = {1, 0, 2},
		is_solid    = true,
		is_pushable = false,
		model       = &game.wall_model,
	}

	append(&game.entities, box)
	append(&game.entities, wall)

	for &entity in game.entities {
		entity.target_pos = entity.pos
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if rl.IsKeyPressed(.F1) {game.editor.active = !game.editor.active}
		if rl.IsKeyPressed(.Z) {undo_move(&game)}

		if !game.editor.active {
			update_game(&game, dt)
		} else {
			update_editor(&game)
		}

		animation_frame += 1
		if animation_frame >= player_animations[0].frameCount {
			animation_frame = 0
		}
		rl.UpdateModelAnimation(game.player_model, player_animations[0], animation_frame)

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(game.camera)
		rl.DrawModelEx(
			game.player_model,
			game.player.pos,
			{0, 1, 0},
			game.player.rotation,
			1,
			rl.WHITE,
		)

		for entity in game.entities {
			rl.DrawModel(entity.model^, entity.pos, 1, rl.WHITE)
		}

		if game.editor.active {
			rl.DrawGrid(100, 1)
			rl.DrawCubeWires(game.editor.preview_pos + {0, 0.5, 0}, 1, 1, 1, rl.RED)
		}

		rl.EndMode3D()
		if game.editor.active {
			entity_amount := rl.TextFormat("Entities: %i", len(game.entities))
			entity_amount_pos := Vector2{10, f32(rl.GetScreenHeight() - FONT_SIZE - 10)}

			rl.DrawTextPro(font, entity_amount, entity_amount_pos, 0, 0, FONT_SIZE, 0, rl.GREEN)

			for type, i in EntityType {
				rec := rl.Rectangle{10, 10 + (70 * f32(i)), 100, 60}
				name := rl.TextFormat("%s", type)

				if rl.CheckCollisionPointRec(rl.GetMousePosition(), rec) {
					game.editor.cursor_busy = true
				}

				if game.editor.current_entity == type {
					rl.GuiSetState(i32(rl.GuiState.STATE_PRESSED))
					rl.GuiButton(rec, name)
					rl.GuiSetState(i32(rl.GuiState.STATE_NORMAL))
				} else {
					if rl.GuiButton(rec, name) {
						game.editor.current_entity = type
					}
				}
			}
		}
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

save_state :: proc(game: ^Game) {
	entities_slice := make([]Entity, len(game.entities))

	for entity, i in game.entities {
		entities_slice[i] = entity
	}

	save_state := State {
		player   = game.player,
		entities = entities_slice,
	}

	append(&game.history, save_state)
}

undo_move :: proc(game: ^Game) {
	if len(game.history) <= 0 {return}
	undo_state := pop(&game.history)
	game.player = undo_state.player
	clear(&game.entities)

	for entity in undo_state.entities {
		append(&game.entities, entity)
	}

	delete(undo_state.entities)
}

move_player :: proc(using game: ^Game) {
	if player.is_moving {return}

	move_direction: Vector3

	if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) {
		move_direction.x -= 1
		player.rotation = 270
	} else if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.D) {
		move_direction.x += 1
		player.rotation = 90
	} else if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) {
		move_direction.z -= 1
		player.rotation = 180
	} else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) {
		move_direction.z += 1
		player.rotation = 0
	}

	if move_direction != 0 {
		save_state(game)

		next_pos := player.pos + move_direction
		collided_entity, _ := get_entity_at_pos(next_pos, game)

		if collided_entity != nil {
			if collided_entity.is_pushable {
				next_entity_pos := collided_entity.pos + move_direction
				if next_entity, _ := get_entity_at_pos(next_entity_pos, game); next_entity != nil {
					return
				}
				collided_entity.target_pos += move_direction
			} else {
				return
			}
		}

		player.target_pos += move_direction
		player.is_moving = true
	}
}

update_game :: proc(using game: ^Game, dt: f32) {
	move_player(game)
	update_entity(&player, dt)

	for &entity in entities {
		update_entity(&entity, dt)
	}

	camera_follow(&camera, &player, CAMERA_OFFSET)
}

update_editor :: proc(using game: ^Game) {
	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), game.camera)

	collision := rl.GetRayCollisionQuad(
		ray,
		{-500, 0, -500},
		{500, 0, -500},
		{500, 0, 500},
		{-500, 0, 500},
	)

	if rl.IsKeyPressed(.ONE) {
		editor.current_entity = .Wall
	} else if rl.IsKeyPressed(.TWO) {
		editor.current_entity = .Box
	}

	if collision.hit {
		editor.preview_pos = {math.round(collision.point.x), 0, math.round(collision.point.z)}
	}

	hovered_entity, entity_index := get_entity_at_pos(editor.preview_pos, game)

	if rl.IsMouseButtonDown(.LEFT) && hovered_entity == nil {
		new_entity := Entity {
			pos        = {editor.preview_pos.x, 0, editor.preview_pos.z},
			target_pos = {editor.preview_pos.x, 0, editor.preview_pos.z},
		}

		switch editor.current_entity {
		case .Wall:
			new_entity.is_solid = true
			new_entity.is_pushable = false
			new_entity.model = &game.wall_model
		case .Box:
			new_entity.is_solid = true
			new_entity.is_pushable = true
			new_entity.model = &game.box_model
		case .Enemy:
			new_entity.is_solid = true
			new_entity.model = &game.wall_model
		}

		append(&game.entities, new_entity)
	}

	if rl.IsMouseButtonDown(.MIDDLE) {
		if entity_index != -1 {
			unordered_remove(&game.entities, entity_index)
		}
	}

	if rl.IsMouseButtonDown(.RIGHT) {
		rl.UpdateCamera(&game.camera, .FREE)
	}

	if rl.IsMouseButtonPressed(.RIGHT) {
		rl.DisableCursor()
	} else if rl.IsMouseButtonReleased(.RIGHT) {
		rl.EnableCursor()
	}
}

camera_follow :: proc(camera: ^rl.Camera, entity: ^Entity, offset: Vector3) {
	camera.position = entity.pos + offset
	camera.target = entity.pos
}

update_entity :: proc(using entity: ^Entity, dt: f32) {
	pos = linalg.lerp(pos, target_pos, dt * ENTITY_SPEED)
	distance_to_target := linalg.length(target_pos - pos)

	if distance_to_target < 0.1 {
		pos = target_pos
		is_moving = false
	}
}

get_entity_at_pos :: proc(pos: [3]f32, using game: ^Game) -> (entity: ^Entity, index: int) {
	for &entity, i in entities {
		if pos == entity.target_pos {
			return &entity, i
		}
	}

	return nil, -1
}
