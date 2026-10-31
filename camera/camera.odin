package camera

import "../hittable"
import "../ray"
import "../vec"
import "../interval"
import "core:math"
import "core:fmt"
import "../image"
import "core:math/rand"
import "core:thread"
import "core:sync/chan"
import runtime "base:runtime"

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
    max_ray_depth: uint,

    vfov: f64,
    lookform: vec.Point3,
    lookat: vec.Point3,
    vup: vec.Vec3,

    u: vec.Vec3,
    v: vec.Vec3,
    w: vec.Vec3,

    defocus_angle: f64,
    focus_distance: f64,
    defocus_disk_u: vec.Vec3,
    defocus_disk_v: vec.Vec3,
}

render :: proc(camera: Camera, img: ^image.Image, world: hittable.Hittable) {
    for y : uint = 0; y < camera.image_height; y += 1 {
        fmt.println("Rows remaining: ", camera.image_height - y)
        for x : uint= 0; x < camera.image_width; x += 1 {
            pixel_color := vec.Color{ 0, 0, 0 }
            for sample := uint(0); sample < camera.samples_per_pixel; sample += 1 {
                r := get_ray(camera, x, y)
                pixel_color += color(r, camera.max_ray_depth, world)
            }

            image.write_pixel(img, pixel_color * camera.pixel_samples_scale)
        }
    }

    image.finish(img)
    fmt.println("Done.")
}

render_threaded :: proc(camera: Camera, img: ^image.Image, world: hittable.Hittable, thread_pool: ^thread.Pool) {
    worker_count := uint(len(thread_pool.threads))
    worker_count = math.min(camera.image_height, worker_count)


    row_buffer_count := worker_count * 2
    row_buffers := make([][]vec.Color, row_buffer_count)
    rows_in_use := make([]bool, row_buffer_count)

    for i := 0; i < len(row_buffers); i += 1 {
        row_buffers[i] = make([]vec.Color, camera.image_width)
    }

    input_ch, err := chan.create_buffered(chan.Chan(RowData), worker_count, context.allocator)
    assert(err == .None)

    send_input_ch := chan.as_send(input_ch)
    recv_input_ch := chan.as_recv(input_ch)

    output_ch, err_2 := chan.create_buffered(chan.Chan(RowRendered), worker_count, context.allocator)
    assert(err_2 == .None)

    send_output_ch := chan.as_send(output_ch)
    recv_output_ch := chan.as_recv(output_ch)

    task_channels := &TaskChannels{
        output_ch = send_output_ch,
        input_ch = recv_input_ch,
    }

    // Launch tasks
    for i := 0; i < int(worker_count); i += 1 {
        thread.pool_add_task(thread_pool, runtime.nil_allocator(), calculate_row, task_channels, i)
    }

    tasks_queued : uint = 0
    need_row : uint = 0
    rendered_rows := make([dynamic]RowRendered, 0, row_buffer_count)
    for y : uint = 0; y < camera.image_height; y += 1 {
        if tasks_queued >= len(row_buffers) {
            row_data, _ := chan.recv(recv_output_ch)
            current_row := row_data

            for current_row.row != need_row {
                append(&rendered_rows, current_row)
                current_row, _ = chan.recv(recv_output_ch)
            }

            for {
                for pixel in row_buffers[current_row.row_buffer_index] {
                    image.write_pixel(img, pixel)
                }

                need_row += 1
                fmt.println("Rows remaining: ", camera.image_height - need_row)
                rows_in_use[current_row.row_buffer_index] = false
                tasks_queued -= 1

                found_new_row := false
                for i := 0; i < len(rendered_rows); i += 1 {
                    other_row := rendered_rows[i]

                    if other_row.row == need_row {
                        current_row = other_row
                        found_new_row = true
                        unordered_remove(&rendered_rows, i)
                        break
                    }
                }

                if !found_new_row {
                    break
                }
            }

        }

        row_buffer_index : int = -1
        for i := 0; i < len(row_buffers); i += 1 {
            if !rows_in_use[i] {
                row_buffer_index = i
                break
            }
        }

        dataToSend := RowData{
            row_buffer_index = row_buffer_index,
            row = y,
            camera = camera,
            world = world,
            row_pixels = row_buffers[row_buffer_index],
        }

        rows_in_use[row_buffer_index] = true
        chan.send(send_input_ch, dataToSend)
        tasks_queued += 1
    }

    chan.close(input_ch)

    for tasks_queued != 0 {
        row_data, _ := chan.recv(recv_output_ch)
        current_row := row_data

        for current_row.row != need_row {
            append(&rendered_rows, current_row)
            current_row, _ = chan.recv(recv_output_ch)
        }

        for {
            for pixel in row_buffers[current_row.row_buffer_index] {
                image.write_pixel(img, pixel)
            }

            need_row += 1
            fmt.println("Rows remaining: ", camera.image_height - need_row)
            rows_in_use[current_row.row_buffer_index] = false
            tasks_queued -= 1

            found_new_row := false
            for other_row in rendered_rows {
                if other_row.row == need_row {
                    current_row = other_row
                    found_new_row = true
                    break
                }
            }

            if !found_new_row {
                break
            }
        }
    }
    chan.close(output_ch)


    // Clear the tasks
    for i : uint = 0; i < worker_count; i += 1 {
        for {
            _, ok := thread.pool_pop_done(thread_pool)

            if ok {
                break
            }

            thread.yield()
        }
    }

    image.finish(img)
    fmt.println("Done.")
}

@(private) RowData :: struct {
    row_buffer_index: int,
    row: uint,
    camera: Camera,
    world: hittable.Hittable,
    row_pixels: []vec.Color,
}

@(private) RowRendered :: struct {
    row_buffer_index: int,
    row: uint,
}

@(private) TaskChannels :: struct {
    input_ch: chan.Chan(RowData, .Recv),
    output_ch: chan.Chan(RowRendered, .Send),
}

@(private) calculate_row :: proc(task: thread.Task) {
    channels := cast(^TaskChannels)task.data
    for {
        row_data, ok := chan.recv(channels.input_ch)
        if !ok {
            break
        }

        for x : uint = 0; x < row_data.camera.image_width; x += 1 {
            pixel_color := vec.Color{ 0, 0, 0 }
            for sample := uint(0); sample < row_data.camera.samples_per_pixel; sample += 1 {
                r := get_ray(row_data.camera, x, row_data.row)
                pixel_color += color(r, row_data.camera.max_ray_depth, row_data.world)
            }

            row_data.row_pixels[x] = pixel_color * row_data.camera.pixel_samples_scale
        }

        chan.send(channels.output_ch, RowRendered{ row_buffer_index = row_data.row_buffer_index, row = row_data.row })
    }
}

default_setup :: proc(image_width: uint, aspect_ratio: f64, samples_per_pixel: uint, vfov: f64, lookfrom: vec.Point3, lookat: vec.Point3, vup: vec.Vec3, defocus_angle: f64, focus_distance: f64) -> Camera {
    image_height := uint(f64(image_width) / aspect_ratio)
    image_height = (image_height < 1) ? 1 : image_height

    camera_center := lookfrom

    // Camera
    theta := math.to_radians(vfov)
    h := math.tan_f64(theta / 2)
    viewport_height := 2 * h * focus_distance
    viewport_width := viewport_height * (f64(image_width) / f64(image_height))

    w := vec.unit(lookfrom - lookat)
    u := vec.unit(vec.cross(vup, w))
    v := vec.cross(w, u)

    viewport_u := viewport_width * u
    viewport_v := viewport_height * -v

    pixel_delta_u := viewport_u / f64(image_width)
    pixel_delta_v := viewport_v / f64(image_height)

    // Upper left pixel
    viewport_upper_left := camera_center - (focus_distance * w) - viewport_u / 2 - viewport_v / 2
    pixel_start_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)

    defocus_radius := focus_distance * math.tan(math.to_radians(defocus_angle / 2))

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
        max_ray_depth = 100,
        vfov = vfov,
        lookform = lookfrom,
        lookat = lookat,
        vup = vup,
        w = w,
        v = v,
        u = u,
        defocus_angle = defocus_angle,
        focus_distance = focus_distance,
        defocus_disk_u = u * defocus_radius,
        defocus_disk_v = v * defocus_radius,
    }
}

color :: proc(r: ray.Ray, depth: uint, world: hittable.Hittable) -> vec.Color {
    if depth <= 0 {
        return vec.Color{ 0, 0, 0 }
    }

    hit, rec := hittable.hit(world, r, interval.Interval{ 0.001, math.INF_F64 })
    if (hit) {
        has_material, attenuation, scattered := hittable.material_scatter(rec.material, r, rec)
        if has_material {
            return attenuation * color(scattered, depth - 1, world)
        }

        return vec.Color{ }
    }

    unit_direction := vec.unit(r.direction)
    a := 0.5 * (unit_direction.y + 1)

    gradient := (1 - a) * vec.Color{ 1, 1, 1 } + a * vec.Color{ 0.5, 0.7, 1.0 }
    return gradient
}

get_ray :: proc(camera: Camera, x: uint, y: uint) -> ray.Ray {
    offset := sample_square()
    pixel_sample := camera.pixel_start +
    ((f64(x) + offset.x) * camera.pixel_delta_u) +
    ((f64(y) + offset.y) * camera.pixel_delta_v)

    ray_origin : vec.Point3
    if camera.defocus_angle <= 0 {
        ray_origin = camera.center
    } else {
        ray_origin = defocus_disk_sample(camera)
    }

    return ray.Ray{
        origin = ray_origin,
        direction = pixel_sample - ray_origin,
    }
}

defocus_disk_sample :: proc(camera: Camera) -> vec.Point3 {
    p := vec.random_on_disk()
//    fmt.println("random point on disk", p)

    return camera.center + (p[0] * camera.defocus_disk_u) + (p[1] * camera.defocus_disk_v)
}

sample_square :: proc() -> vec.Point3 {
    return vec.Point3{ rand.float64() - 0.5, rand.float64() - 0.5, 0 }
}