package frog_knight

vec3_to_vec3i :: proc(vec3: Vec3) -> Vec3i {
	return {i32(vec3.x), i32(vec3.y), i32(vec3.z)}
}

vec3i_to_vec3 :: proc(vec3i: Vec3i) -> Vec3 {
	return {f32(vec3i.x), f32(vec3i.y), f32(vec3i.z)}
}
