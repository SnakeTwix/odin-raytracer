package hittable

import "../vec"
import "../ray"

Material :: union {
    Lambertian,
    Metal,
}

material_scatter :: proc(material: Material, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray){
    switch mat in material {
    case Lambertian:
        return lambertian_scatter(mat, r, rec)
    case Metal:
        return metal_scatter(mat, r, rec)
    }

    return false, vec.Color{}, ray.Ray{}
}


Lambertian :: struct {
    albedo: vec.Color,
}

lambertian_scatter :: proc(material: Lambertian, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    scatter_direction := rec.normal + vec.random_unit_sphere()
    if vec.is_near_zero(scatter_direction) {
        scatter_direction = rec.normal
    }

    scattered := ray.Ray{origin = rec.point, direction = scatter_direction}
    attenuation := material.albedo

    return true, attenuation, scattered
}

Metal :: struct {
    albedo: vec.Color,
}

metal_scatter :: proc(material: Metal, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    reflected := vec.reflect(r.direction, rec.normal)
    scattered := ray.Ray{origin = rec.point, direction = reflected}
    attenuation := material.albedo

    return true, attenuation, scattered
}


