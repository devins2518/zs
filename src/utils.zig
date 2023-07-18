const std = @import("std");

pub fn Field(comptime ty: type, comptime field: anytype) type {
    comptime {
        return std.meta.fieldInfo(ty, field).type;
    }
}
