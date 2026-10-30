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
    WIDTH :: 1920
    ASPECT_RATIO :: 16.0 / 9.0
    CAMERA_SAMPLE_PER_PIXEL :: 100
    THREAD_COUNT :: 12

    thread_pool : thread.Pool

    thread.pool_init(&thread_pool, context.allocator, THREAD_COUNT)

    // World
    world : hittable.List
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, 0, -1 }, radius = 0.5 })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, -100.5, -1 }, radius = 100 })

    cam := camera.default_setup(WIDTH, ASPECT_RATIO, CAMERA_SAMPLE_PER_PIXEL)

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



