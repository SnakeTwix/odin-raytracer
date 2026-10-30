package ray

import "../vec"

Ray :: struct {
    origin: vec.Point3,
    direction: vec.Vec3,
}

at :: proc(ray: Ray, t: f64) -> vec.Point3 {
    return ray.origin + t * ray.direction
}

