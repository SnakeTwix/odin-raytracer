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
}

render :: proc(camera: Camera, img: ^image.Image, world: hittable.Hittable) {
    for y : uint = 0; y < camera.image_height; y += 1 {
        fmt.println("Rows remaining: ", camera.image_height - y)
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

render_threaded :: proc(camera: Camera, img: ^image.Image, world: hittable.Hittable, thread_pool: ^thread.Pool) {
    amount_of_tasks_to_schedule := uint(len(thread_pool.threads)) * 2
    amount_of_tasks_to_schedule = math.min(camera.image_height, amount_of_tasks_to_schedule)

    row_buffers := make([][]vec.Color, amount_of_tasks_to_schedule)
    rows_in_use := make([]bool, amount_of_tasks_to_schedule)

    for i := 0; i < len(row_buffers); i += 1 {
        row_buffers[i] = make([]vec.Color, camera.image_width)
    }

    input_ch, err := chan.create_buffered(chan.Chan(RowData), amount_of_tasks_to_schedule, context.allocator)
    assert(err == .None)

    send_input_ch := chan.as_send(input_ch)
    recv_input_ch := chan.as_recv(input_ch)

    output_ch, err_2 := chan.create_buffered(chan.Chan(RowData), amount_of_tasks_to_schedule, context.allocator)
    assert(err_2 == .None)

    send_output_ch := chan.as_send(output_ch)
    recv_output_ch := chan.as_recv(output_ch)

    task_channels := &TaskChannels{
        output_ch = send_output_ch,
        input_ch = recv_input_ch,
    }

    // Launch tasks
    for i := 0; i < int(amount_of_tasks_to_schedule); i += 1 {
        thread.pool_add_task(thread_pool, runtime.nil_allocator(), calculate_row, task_channels, i)
    }

    tasks_queued : uint = 0
    need_row : uint = 0
    rendered_rows := make([dynamic]RowData, 0, amount_of_tasks_to_schedule)
    for y : uint = 0; y < camera.image_height; y += 1 {
        if tasks_queued >= amount_of_tasks_to_schedule {
            row_data, _ := chan.recv(recv_output_ch)
            current_row := row_data

            for current_row.row != need_row {
                append(&rendered_rows, current_row)
                current_row, _ = chan.recv(recv_output_ch)
            }

            for {
                for pixel in current_row.row_pixels {
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

        row_buffer_index: int = -1
        for i := 0; i < int(amount_of_tasks_to_schedule); i += 1 {
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
            for pixel in current_row.row_pixels {
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
    for i : uint = 0; i < amount_of_tasks_to_schedule; i += 1 {
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

@(private) TaskChannels :: struct {
    input_ch: chan.Chan(RowData, .Recv),
    output_ch: chan.Chan(RowData, .Send),
}

@(private) calculate_row :: proc(task: thread.Task) {
    channels := cast(^TaskChannels)task.data
    for {
        rowData, ok := chan.recv(channels.input_ch)
        if !ok {
            break
        }

        for x : uint = 0; x < rowData.camera.image_width; x += 1 {
            pixel_color := vec.Color{ 0, 0, 0 }
            for sample := uint(0); sample < rowData.camera.samples_per_pixel; sample += 1 {
                r := get_ray(rowData.camera, x, rowData.row)
                pixel_color += color(r, rowData.world)
            }

            rowData.row_pixels[x] = pixel_color * rowData.camera.pixel_samples_scale
        }

        chan.send(channels.output_ch, rowData)
    }
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