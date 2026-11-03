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
import "core:math/rand"
import "core:mem"

_ :: mem

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator

        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }

    }

    WIDTH :: 400
    ASPECT_RATIO :: 16.0 / 9.0
    CAMERA_SAMPLE_PER_PIXEL :: 5
    THREAD_COUNT :: 6

    thread_pool : thread.Pool

    thread.pool_init(&thread_pool, context.allocator, THREAD_COUNT)

    // Materials
    material_ground := hittable.Lambertian{ albedo = vec.Color{ .5, .5, .5 } }

    // World
    world : hittable.List
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, -10000, 0 }, radius = 10000, material = material_ground })

    for a := -11; a < 11; a += 1 {
        for b := -11; b < 11; b += 1 {
            choose_mat := rand.float64()
            center := vec.Point3{ f64(a) + 0.9 * rand.float64(), 0.2, f64(b) + 0.9 * rand.float64() }

            if choose_mat < 0.8 {
            // diffuse
                albedo := vec.random() * vec.random()
                sphere_material := hittable.Lambertian{ albedo = albedo }
                hittable.list_add(&world, hittable.Sphere{ center = center, radius = 0.2, material = sphere_material })
            } else if choose_mat < 0.95 {
            // metal
                albedo := vec.random_ranged(0.5, 1)
                fuzz := rand.float64_range(0, 0.5)
                sphere_material := hittable.Metal{ albedo = albedo, fuzz = fuzz }
                hittable.list_add(&world, hittable.Sphere{ center = center, radius = 0.2, material = sphere_material })
            } else {
            // glass
                albedo := vec.random_ranged(0.95, 1)
                material := hittable.Dielectric{ albedo = albedo, refraction_index = 1.5 }
                hittable.list_add(&world, hittable.Sphere{ center = center, radius = 0.2, material = material })
            }
        }
    }

    material1 := hittable.Dielectric{ albedo = vec.Color{ 1, 1, 1 }, refraction_index = 1.5 }
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, 1, 0 }, radius = 1, material = material1 })

    material2 := hittable.Lambertian{ albedo = vec.Color{ .4, .2, .1 } }
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ -4, 1, 0 }, radius = 1, material = material2 })

    material3 := hittable.Metal{ albedo = vec.Color{ 0.7, 0.6, 0.5 }, fuzz = 0.0 }
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 4, 1, 0 }, radius = 1, material = material3 })

    cam := camera.default_setup(
    image_width=WIDTH,
    aspect_ratio=ASPECT_RATIO,
    samples_per_pixel=CAMERA_SAMPLE_PER_PIXEL,

    vfov=20,
    lookfrom=vec.Point3{ 13, 2, 3 },
    lookat=vec.Point3{ 0, 0, 0 },
    vup=vec.Point3{ 0, 1, 0 },

    defocus_angle = .6,
    focus_distance = 10,
    )

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

    delete(world.hittables)
    // The thread can leaving hanging if don't wait for the pool to finish before freeing
    thread.pool_join(&thread_pool)
    thread.pool_destroy(&thread_pool)
}



