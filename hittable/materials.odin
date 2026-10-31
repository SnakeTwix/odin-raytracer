package hittable

import "../vec"
import "../ray"
import fmt "core:fmt"
import math "core:math"
import rand "core:math/rand"

Material :: union {
    Lambertian,
    Metal,
    Dielectric,
}

material_scatter :: proc(material: Material, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    switch mat in material {
    case Lambertian:
        return lambertian_scatter(mat, r, rec)
    case Metal:
        return metal_scatter(mat, r, rec)
    case Dielectric:
        return dielectric_scatter(mat, r, rec)
    }

    return false, vec.Color{ }, ray.Ray{ }
}


Lambertian :: struct {
    albedo: vec.Color,
}

lambertian_scatter :: proc(material: Lambertian, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    scatter_direction := rec.normal + vec.random_unit_sphere()
    if vec.is_near_zero(scatter_direction) {
        scatter_direction = rec.normal
    }

    scattered := ray.Ray{ origin = rec.point, direction = scatter_direction }
    attenuation := material.albedo

    return true, attenuation, scattered
}

Metal :: struct  #all_or_none {
    albedo: vec.Color,
    fuzz: f64,
}

metal_scatter :: proc(material: Metal, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    reflected := vec.reflect(r.direction, rec.normal)
    reflected = vec.unit(reflected) + (material.fuzz * vec.random_unit_sphere())

    scattered := ray.Ray{ origin = rec.point, direction = reflected }
    attenuation := material.albedo

    return true, attenuation, scattered
}

Dielectric :: struct #all_or_none {
    albedo: vec.Color,
    refraction_index: f64
}

dielectric_scatter :: proc(material: Dielectric, r: ray.Ray, rec: HitRecord) -> (bool, vec.Color, ray.Ray) {
    refraction_index : f64

    if rec.front_face {
        refraction_index = 1.0 / material.refraction_index
    } else {
        refraction_index = material.refraction_index
    }

    unit_direction := vec.unit(r.direction)
    cos_theta := min(1, vec.dot(-unit_direction, rec.normal))
    sin_theta := math.sqrt(1.0 - cos_theta * cos_theta)

    cannot_refract := refraction_index * sin_theta > 1.0
    direction : vec.Vec3

    if cannot_refract || reflectance(cos_theta, refraction_index) > rand.float64() {
        direction = vec.reflect(unit_direction, rec.normal)
    } else {
        direction = vec.refract(unit_direction, rec.normal, refraction_index)
    }

    scattered := ray.Ray{ rec.point, direction }
    return true, material.albedo, scattered
}

reflectance :: proc(cosine: f64, refraction_index: f64) -> f64 {
    r0 := (1 - refraction_index) / (1 + refraction_index)
    r0 *= r0

    return r0 + (1 - r0) * math.pow(1 - cosine, 5)
}

