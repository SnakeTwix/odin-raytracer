package vec

import "core:math"

Vec3 :: [3]f64

length_squared :: proc(vec: Vec3) -> f64 {
    return vec.x * vec.x + vec.y * vec.y + vec.z * vec.z
}

length :: proc(vec: Vec3) -> f64 {
    return math.sqrt_f64(length_squared(vec))
}

unit :: proc(vec: Vec3) -> Vec3 {
    return vec / length(vec)
}

dot :: proc(vec1: Vec3, vec2: Vec3) -> f64 {
    return vec1.x * vec2.x + vec1.y * vec2.y + vec1.z * vec2.z
}
Color :: Vec3

Point3 :: Vec3