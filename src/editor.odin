package frog_knight

import "core:math"
import rl "vendor:raylib"

Editor :: struct {
	active:         bool,
	current_entity: EntityType,
	preview_pos:    Vec3,
	cursor_busy:    bool,
	y_layer:        i32,
}

update_editor :: proc(using game: ^Game) {
	editor.cursor_busy = false

	if rl.GetMouseWheelMove() > 0 {
		editor.y_layer += 1
	} else if rl.GetMouseWheelMove() < 0 {
		editor.y_layer -= 1
	}

	for type, i in EntityType {
		rec := get_editor_button_rec(i)
		if rl.CheckCollisionPointRec(rl.GetMousePosition(), rec) {
			game.editor.cursor_busy = true
		}
	}

	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), game.camera)

	collision := rl.GetRayCollisionQuad(
		ray,
		{-500, f32(editor.y_layer), -500},
		{500, f32(editor.y_layer), -500},
		{500, f32(editor.y_layer), 500},
		{-500, f32(editor.y_layer), 500},
	)

	if rl.IsKeyPressed(.ONE) {
		editor.current_entity = .Wall
	} else if rl.IsKeyPressed(.TWO) {
		editor.current_entity = .Box
	}

	if collision.hit {
		editor.preview_pos = {
			math.round(collision.point.x),
			f32(editor.y_layer),
			math.round(collision.point.z),
		}
	}

	hovered_entity, entity_index := get_entity_at_pos(vec3_to_vec3i(editor.preview_pos), game)

	if rl.IsMouseButtonDown(.LEFT) && hovered_entity == nil && !editor.cursor_busy {
		entity_pos := Vec3i{i32(editor.preview_pos.x), editor.y_layer, i32(editor.preview_pos.z)}

		new_entity := create_entity(editor.current_entity, entity_pos)

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

draw_editor :: proc(game: ^Game, font: rl.Font) {
	entity_amount := rl.TextFormat("Entities: %i", len(game.entities))
	entity_amount_pos := Vec2{10, f32(rl.GetScreenHeight() - FONT_SIZE - 10)}

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

get_editor_button_rec :: proc(index: int) -> rl.Rectangle {
	return rl.Rectangle{10, 10 + (70 * f32(index)), 100, 60}

}
