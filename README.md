# Odin raytracer

------

Raytracer written following the [first book](https://raytracing.github.io/books/RayTracingInOneWeekend.html) in the [Ray Tracing in One Weekend](https://raytracing.github.io) book series.

## Implementation Details

------

As the spirit of the book goes - this is pretty much a 1-to-1 implementation of the C++ code the book provides with no external dependencies apart from what the odin language provides, with some additional features

- Multithreading: You can specify the amount of threads you want to use in the [main](./main.odin) file with the `THREAD_COUNT` constant.


- Albedo for glass materials: The book for some reason doesn't actually implement albedo for glass materials, this is pretty much a one line addition


- P3/P6 Image output: The original book only ever gets into outputting the image in P3 .ppm format, however because the file size is extremely huge, there is an interchangeable implementation for outputting the image in P6 format, which, in practice, results in ~3-4x times smaller image sizes


- No memory leaks!