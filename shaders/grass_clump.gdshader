// Grass tufts: like foliage.gdshader, but without alpha test (the grass texture is opaque),
// so the GPU can use the early depth test.
shader_type spatial;
#define OPAQUE_GRASS
render_mode cull_disabled, specular_disabled;

#include "res://shaders/foliage_body.gdshaderinc"
