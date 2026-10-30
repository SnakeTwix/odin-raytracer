package camera

import "../hittable"
import "../ray"
import "../vec"
import "../interval"
import "core:math"
import "core:fmt"
import "../image"
import "core:math/rand"

Camera :: struct #all_or_none {
    aspect_ratio: f64,
    pixel_samples_scale: f64,
    image_width: uint,
    image_height: uint,
    center: vec.Point3,
    pixel_start: vec.Point3,
    pixel_delta_u: vec.Vec3,
    pixel_delta_v: vec.Vec3,
    samples_per_pixel: uint,
}

render :: proc(camera: Camera, img: ^image.Image, world: hittable.Hittable) {
    for y : uint = 0; y < camera.image_height; y += 1 {
        fmt.println("Scanlines remaining: ", camera.image_height - y)
        for x : uint= 0; x < camera.image_width; x += 1 {
            pixel_color := vec.Color{ 0, 0, 0 }
            for sample := uint(0); sample < camera.samples_per_pixel; sample += 1 {
                r := get_ray(camera, x, y)
                pixel_color += color(r, world)
            }

            image.write_pixel(img, pixel_color * camera.pixel_samples_scale)
        }
    }

    image.finish(img)
    fmt.println("Done.")
}

default_setup :: proc(image_width: uint, aspect_ratio: f64, samples_per_pixel: uint) -> Camera {
    image_height := uint(f64(image_width) / aspect_ratio)
    image_height = (image_height < 1) ? 1 : image_height

    // Camera
    focal_length := 1.0
    viewport_height := 2.0
    viewport_width := viewport_height * (f64(image_width) / f64(image_height))

    camera_center := vec.Point3{ 0, 0, 0 }

    viewport_u := vec.Vec3{ viewport_width, 0, 0 }
    viewport_v := vec.Vec3{ 0, -viewport_height, 0 }

    pixel_delta_u := viewport_u / f64(image_width)
    pixel_delta_v := viewport_v / f64(image_height)

    // Upper left pixel
    viewport_upper_left := camera_center - vec.Vec3{ 0, 0, focal_length } - viewport_u / 2 - viewport_v / 2
    pixel_start_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)

    return Camera{
        image_height = image_height,
        image_width = image_width,
        aspect_ratio = aspect_ratio,
        center = camera_center,
        pixel_delta_v = pixel_delta_v,
        pixel_delta_u = pixel_delta_u,
        pixel_start = pixel_start_loc,
        samples_per_pixel = samples_per_pixel,
        pixel_samples_scale = 1.0 / f64(samples_per_pixel),
    }
}

color :: proc(ray: ray.Ray, world: hittable.Hittable) -> vec.Color {
    hit, rec := hittable.hit(world, ray, interval.Interval{ 0, math.INF_F64 })
    if (hit) {
        return 0.5 * (rec.normal + 1)
    }

    unit_direction := vec.unit(ray.direction)
    a := 0.5 * (unit_direction.y + 1)

    gradient := (1 - a) * vec.Color{ 1, 1, 1 } + a * vec.Color{ 0.5, 0.7, 1.0 }
    return gradient
}

get_ray :: proc(camera: Camera, x: uint, y: uint) -> ray.Ray {
    offset := sample_square()
    pixel_sample := camera.pixel_start +
    ((f64(x) + offset.x) * camera.pixel_delta_u) +
    ((f64(y) + offset.y) * camera.pixel_delta_v)

    return ray.Ray{
        origin = camera.center,
        direction = pixel_sample - camera.center,
    }
}

sample_square :: proc() -> vec.Point3 {
    return vec.Point3{ rand.float64() - 0.5, rand.float64() - 0.5, 0 }
}