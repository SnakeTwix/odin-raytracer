package interval

import "core:math"

Interval :: struct {
    min: f64,
    max: f64,
}

size :: proc(interval: Interval) -> f64 {
    return interval.max - interval.min
}

contains :: proc(interval: Interval, x: f64) -> bool {
    return interval.min <= x && x <= interval.max
}

surrounds :: proc(interval: Interval, x: f64) -> bool {
    return interval.min < x && x < interval.max
}

clamp :: proc(interval: Interval, x: f64) -> f64 {
    if x < interval.min {
        return interval.min
    }

    if x > interval.max {
        return interval.max
    }

    return x
}

Empty :: Interval{ min = math.INF_F64, max = math.NEG_INF_F64 }
All :: Interval{ min = math.NEG_INF_F64, max = math.INF_F64 }
