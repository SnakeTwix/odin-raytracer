package raytracer

import "core:os"
import "core:fmt"
import bufio "core:bufio"
import "vec"
import "hittable"
import "camera"
import "image"
import thread "core:thread"
import time "core:time"

main :: proc() {
    WIDTH :: 400
    ASPECT_RATIO :: 16.0 / 9.0
    CAMERA_SAMPLE_PER_PIXEL :: 500
    THREAD_COUNT :: 12

    thread_pool : thread.Pool

    thread.pool_init(&thread_pool, context.allocator, THREAD_COUNT)

    // Materials
    material_ground := hittable.Lambertian{ albedo = vec.Color{ .8, .8, .0 } }
    material_center := hittable.Lambertian{ albedo = vec.Color{ .1, .2, .5 } }
    material_left := hittable.Dielectric{ albedo = vec.Color{ 1, 1, 1 }, refraction_index = 1.5 }
    material_bubble := hittable.Dielectric{ albedo = vec.Color{ 1, 1, 1 }, refraction_index = 1.0 / 1.5 }
    material_right := hittable.Metal{ albedo = vec.Color{ .8, .6, .2 }, fuzz = 0.05 }

    // World
    world : hittable.List
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, -100.5, -1 }, radius = 100, material = material_ground })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, 0, -1.5 }, radius = 0.5, material = material_center })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ -1, 0, -1 }, radius = 0.5, material = material_left })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ -1, 0, -1 }, radius = 0.4, material = material_bubble })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 1, 0, -1 }, radius = 0.5, material = material_right })

    cam := camera.default_setup(
    image_width=WIDTH,
    aspect_ratio=ASPECT_RATIO,
    samples_per_pixel=CAMERA_SAMPLE_PER_PIXEL,
    vfov=90,
    lookfrom=vec.Point3{ 0, 0, 0 },
    lookat=vec.Point3{ 0, 0, -1 },
    vup=vec.Point3{ 0, 1, 0 }
    )

    fmt.println("camera: ", cam)

    file, err := os.create("./out/out.ppm")
    if err != nil {
        fmt.eprintln(err)
        return
    }

    writer_buf : [1024 * 64]u8
    writer : bufio.Writer
    bufio.writer_init_with_buf(&writer, os.to_stream(file), writer_buf[:])
    img := image.Image{
        width = cam.image_width,
        height = cam.image_height,
        writer = writer,
        type = image.Type.Ppm_P6,
    }

    start_time := time.tick_now()
    image.write_header(&img)

    thread.pool_start(&thread_pool)
    camera.render_threaded(cam, &img, world, &thread_pool)
    //    camera.render(cam, &img, world)

    elapsed := time.tick_since(start_time)
    fmt.println("Rendering took: ", time.duration_milliseconds(elapsed), "ms")
}



