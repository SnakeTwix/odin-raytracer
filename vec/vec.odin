package vec

import "core:math"
import "core:math/rand"

Vec3 :: [3]f64

Color :: Vec3

Point3 :: Vec3

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

cross :: proc(vec1: Vec3, vec2: Vec3) -> Vec3 {
    i := vec1.yzx * vec2.zxy
    j := vec1.zxy * vec2.yzx
    return i - j
}
random :: proc() -> Vec3 {
    return Vec3{ rand.float64(), rand.float64(), rand.float64() }
}

random_ranged :: proc(min, max: f64) -> Vec3 {
    return Vec3{
        rand.float64_range(min, max),
        rand.float64_range(min, max),
        rand.float64_range(min, max),
    }
}

random_unit_sphere :: proc() -> Vec3 {
    for {
        v := random_ranged(-1, 1)
        lensq := length_squared(v)
        if (1e-160 < lensq && lensq <= 1) {
            return v / math.sqrt(lensq)
        }
    }
}

random_on_hempishere :: proc(normal: Vec3) -> Vec3 {
    sphere_vec := random_unit_sphere()

    if dot(sphere_vec, normal) > 0 {
        return sphere_vec
    }

    return -sphere_vec
}

is_near_zero :: proc(vec: Vec3) -> bool {
    threshold :: 1e-8

    return abs(vec.x) < threshold && abs(vec.y) < threshold && abs(vec.z) < threshold
}

reflect :: proc(vec: Vec3, normal: Vec3) -> Vec3 {
    return vec - 2 * dot(vec, normal) * normal
}

refract :: proc(vec: Vec3, normal: Vec3, refractor: f64) -> Vec3 {
    cos_theta := min(dot(-vec, normal), 1.0)
    r_out_perp := refractor * (vec + cos_theta * normal)
    r_out_parallel := -math.sqrt(abs(1 - length_squared(r_out_perp))) * normal

    return r_out_perp + r_out_parallel
}