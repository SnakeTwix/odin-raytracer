package hittable

import "../vec"
import "../ray"
import "../interval"
import "core:math"

// Hittables
HitRecord :: struct {
    point: vec.Point3,
    normal: vec.Vec3,
    t: f64,
    front_face: bool,
    material: Material,
}

Hittable :: union {
    Sphere,
    List,
}

Sphere :: struct #all_or_none {
    center: vec.Point3,
    radius: f64,
    material: Material,
}

hit_sphere :: proc(sphere: Sphere, r: ray.Ray, ray_t: interval.Interval) -> (bool, HitRecord) {
    oc := sphere.center - r.origin
    a := vec.length_squared(r.direction)
    h := vec.dot(r.direction, oc)
    c := vec.length_squared(oc) - sphere.radius * sphere.radius
    discriminant := h * h - a * c

    if (discriminant < 0) {
        return false, HitRecord { }
    }

    sqrtd := math.sqrt_f64(discriminant)
    root := (h - sqrtd) / a

    if !interval.surrounds(ray_t, root) {
        root = (h + sqrtd) / a
        if !interval.surrounds(ray_t, root) {
            return false, HitRecord { }
        }
    }

    hr := HitRecord { }
    hr.t = root
    hr.point = ray.at(r, hr.t)
    hr.material = sphere.material

    outward_normal := (hr.point - sphere.center) / sphere.radius

    if vec.dot(r.direction, outward_normal) < 0 {
        hr.normal = outward_normal
        hr.front_face = true
    } else {
        hr.normal = -outward_normal
        hr.front_face = false
    }

    return true, hr
}

// Hittable list
List :: struct {
    hittables: [dynamic]Hittable,
}

hit_list :: proc(hittable_list: List, ray: ray.Ray, ray_t: interval.Interval) -> (bool, HitRecord) {
    hr := HitRecord { }
    hit_anything := false
    closest_so_far := ray_t.max

    for hittable in hittable_list.hittables {
        current_hit, current_hr := hit(hittable, ray, interval.Interval{ray_t.min, closest_so_far})
        if current_hit {
            hit_anything = true
            closest_so_far = current_hr.t
            hr = current_hr
        }
    }

    return hit_anything, hr
}

list_add :: proc (list: ^List, hittable: Hittable) {
    append(&list.hittables, hittable)
}

hit :: proc(hittable: Hittable, ray: ray.Ray, ray_t: interval.Interval) -> (bool, HitRecord) {
    switch shape in hittable {
    case Sphere:
        return hit_sphere(shape, ray, ray_t)
    case List:
        return hit_list(shape, ray, ray_t)
    }

    return false, HitRecord{ }
}

