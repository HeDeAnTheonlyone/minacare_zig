const std = @import("std");

pub const CallbackFn = *const fn(ctx: *anyopaque, param: ?usize) anyerror!void;
    
pub const Callback = struct {
    func: CallbackFn,
    ctx: *anyopaque,

    const Self = @This();

    /// param is a generic parameter that is used to hold simple values or pointers.
    pub fn call(self: *const Self, param: ?usize) !void {
        try self.func(self.ctx, param);
    }
};

pub const CallbackCaster = struct {
    pub fn packParam(value: anytype) ?usize {
        const T = @TypeOf(value);
        if (T == @TypeOf(null)) return null;

        return if (@typeInfo(T) == .pointer) @intFromPtr(value)
        else blk: {
            const t_sized_int = @Type( .{ .int = .{
                .signedness = .unsigned,
                .bits = @bitSizeOf(T),
            }});

            break :blk @as(t_sized_int, @bitCast(value));
        };
    }

    pub fn unpackParam(comptime T: type, value: usize) T {   
        return if (@typeInfo(T) == .pointer) @ptrFromInt(value)
        else blk: {
            const t_sized_int = @Type( .{ .int = .{
                .signedness = .unsigned,
                .bits = @bitSizeOf(T),
            }});

            break :blk @bitCast(@as(t_sized_int, @intCast(value)));
        };
    }
};
