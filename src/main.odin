package frog_knight

import "core:os"
import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "Frog Knight")
	rl.SetTargetFPS(60)

	font := rl.LoadFontEx("../res/fonts/AtkinsonHyperlegibleNext-Regular.ttf", FONT_SIZE, nil, 0)
	rl.GuiSetFont(font)
	rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), FONT_SIZE)

	game := Game {
		player = {is_solid = true},
		camera = {up = {0, 1, 0}, fovy = 45, projection = .PERSPECTIVE},
		assets = {
			player_model = rl.LoadModel("../res/models/player.glb"),
			box_model = rl.LoadModel("../res/models/box.glb"),
			wall_model = rl.LoadModel("../res/models/wall.glb"),
			grass_model = rl.LoadModel("../res/models/grass.glb"),
			enemy_model = rl.LoadModel("../res/models/enemy.glb"),
		},
		turn = .Player,
	}

	animation_frame: i32

	animation_count: i32
	player_animations := rl.LoadModelAnimations("../res/models/player.glb", &animation_count)

	material_texture := rl.LoadTexture("../res/resurrect-64.png")

	rl.SetTextureFilter(material_texture, .BILINEAR)

	rl.SetMaterialTexture(&game.assets.box_model.materials[1], .ALBEDO, material_texture)
	rl.SetMaterialTexture(&game.assets.wall_model.materials[1], .ALBEDO, material_texture)
	rl.SetMaterialTexture(&game.assets.player_model.materials[1], .ALBEDO, material_texture)
	rl.SetMaterialTexture(&game.assets.grass_model.materials[1], .ALBEDO, material_texture)

	if os.exists("../world.json") {
		load_game_from_file(&game, "../world.json")
	}

	for &entity in game.entities {
		entity.target_pos = entity.pos
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if rl.IsKeyPressed(.F1) {game.editor.active = !game.editor.active}
		if rl.IsKeyPressed(.F5) {save_game_to_file(&game, "../world.json")}
		if rl.IsKeyPressed(.F9) {load_game_from_file(&game, "../world.json")}
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

		rl.UpdateModelAnimation(game.assets.player_model, player_animations[0], animation_frame)

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(game.camera)
		rl.DrawModelEx(
			game.assets.player_model,
			game.player.pos,
			{0, 1, 0},
			game.player.rotation,
			1,
			rl.WHITE,
		)

		for entity in game.entities {
			entity_model := get_entity_model(entity.type, &game)
			rl.DrawModel(entity_model^, entity.pos, 1, rl.WHITE)
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
				rec := get_editor_button_rec(i)
				name := rl.TextFormat("%s", type)

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
