package image

import "../vec"
import "../interval"
import "core:bufio"
import "core:fmt"
import math "core:math"

Image :: struct {
    height: uint,
    width: uint,
    writer: bufio.Writer,
    type: Type,
}

Type :: enum {
    Ppm_P6,
    Ppm_P3,
}

linear_to_gamma :: proc(x: f64) -> f64 {
    if x > 0 {
        return math.sqrt(x)
    }

    return 0
}

write_header :: proc(image: ^Image) {
    switch (image.type) {
    case Type.Ppm_P3:
        write_header_ppm_p3(image)
    case Type.Ppm_P6:
        write_header_ppm_p6(image)
    }
}

write_header_ppm_p6 :: proc(image: ^Image) {
    headerBuf: [32]u8
    headerStr := fmt.bprintf(headerBuf[:], "P6\n%d %d\n255\n", image.width, image.height)

    bufio.writer_write_string(&image.writer, headerStr)
}

write_header_ppm_p3 :: proc(image: ^Image) {
    headerBuf : [32]u8
    headerStr := fmt.bprintf(headerBuf[:], "P3\n%d %d\n255\n", image.width, image.height)

    bufio.writer_write_string(&image.writer, headerStr)
}

write_pixel :: proc(image: ^Image, color: vec.Color) {
    switch (image.type) {
    case Type.Ppm_P3:
        write_pixel_p3(image, color)
    case Type.Ppm_P6:
        write_pixel_p6(image, color)
    }
}

write_pixel_p6 :: proc(image: ^Image, color: vec.Color) {
    intensity :: interval.Interval{ 0, 0.999 }

    pixelBuf := [3]u8{
        u8(256 * interval.clamp(intensity, linear_to_gamma(color.r))),
        u8(256 * interval.clamp(intensity, linear_to_gamma(color.g))),
        u8(256 * interval.clamp(intensity, linear_to_gamma(color.b))),
    }
    pixel := pixelBuf[:]

    bufio.writer_write(&image.writer, pixel)
}

write_pixel_p3 :: proc(image: ^Image, color: vec.Color) {
    intensity :: interval.Interval{ 0, 0.999 }

    pixelBuf : [len("255 255 255\n")]u8
    pixel := pixelBuf[:]
    pixelStr : string

    ir := u64(256 * interval.clamp(intensity, linear_to_gamma(color.r)))
    ig := u64(256 * interval.clamp(intensity, linear_to_gamma(color.g)))
    ib := u64(256 * interval.clamp(intensity, linear_to_gamma(color.b)))

    pixelStr = fmt.bprintf(pixel, "%d %d %d\n", ir, ig, ib)
    bufio.writer_write_string(&image.writer, pixelStr)
}

finish :: proc(image: ^Image) {

    err := bufio.writer_flush(&image.writer)
    if err != nil {
        fmt.eprintln(err)
        return
    }
}