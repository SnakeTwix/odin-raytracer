package raytracer

import "core:os"
import "core:fmt"
import bufio "core:bufio"
import "vec"
import "hittable"
import "camera"

main :: proc() {
    WIDTH :: 400
    ASPECT_RATIO :: 16.0 / 9.0

    // World
    world : hittable.List
    //    defer delete(world.hittables)
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, 0, -1 }, radius = 0.5 })
    hittable.list_add(&world, hittable.Sphere{ center = vec.Point3{ 0, -100.5, -1 }, radius = 100 })

    cam := camera.default_setup(WIDTH, ASPECT_RATIO)

    file, err := os.create("./out/out.ppm")
    if err != nil {
        fmt.eprintln(err)
        return
    }

    writer_buf : [1024 * 64]u8
    writer : bufio.Writer
    bufio.writer_init_with_buf(&writer, os.to_stream(file), writer_buf[:])

    camera.render(cam, &writer, world)
}



