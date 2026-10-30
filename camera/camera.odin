package camera

import "../hittable"
import "../ray"
import "../vec"
import "../interval"
import "core:math"
import "core:bufio"
import "core:fmt"

Camera :: struct #all_or_none {
    aspect_ratio: f64,
    image_width: uint,
    image_height: uint,
    center: vec.Point3,
    pixel_start: vec.Point3,
    pixel_delta_u: vec.Vec3,
    pixel_delta_v: vec.Vec3,
}

render :: proc(camera: Camera, writer: ^bufio.Writer, world: hittable.Hittable) {
    headerBuf : [32]u8
    headerStr := fmt.bprintf(headerBuf[:], "P3\n%d %d\n255\n", camera.image_width, camera.image_height)

    bufio.writer_write_string(writer, headerStr)

    for y : uint = 0; y < camera.image_height; y += 1 {
        fmt.println("Scanlines remaining: ", camera.image_height - y)
        for x : uint= 0; x < camera.image_width; x += 1 {

            pixel_center := camera.pixel_start + (f64(x) * camera.pixel_delta_u) + (f64(y) * camera.pixel_delta_v)
            ray_direction := pixel_center - camera.center
            r := ray.Ray{ camera.center, ray_direction }

            pixel_color := color(r, world)

            write_color(writer, pixel_color)
        }
    }

    // Flush any remaining buffered data.
    err := bufio.writer_flush(writer)
    if err != nil {
        fmt.eprintln(err)
        return
    }

    fmt.println("Done.")
}

default_setup :: proc(image_width: uint, aspect_ratio: f64) -> Camera {
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

write_color :: proc(writer: ^bufio.Writer, color: vec.Color) {
    pixelBuf : [len("255 255 255\n")]u8
    pixel := pixelBuf[:]
    pixelStr : string

    ir := u64(255.999 * color.r)
    ig := u64(255.999 * color.g)
    ib := u64(255.999 * color.b)

    pixelStr = fmt.bprintf(pixel, "%d %d %d\n", ir, ig, ib)
    bufio.writer_write_string(writer, pixelStr)
}