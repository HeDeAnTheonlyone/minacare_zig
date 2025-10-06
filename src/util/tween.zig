const std = @import("std");
const rl = @import("raylib");
const lib = @import("../lib.zig");
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

var allocator: Allocator = undefined;
const max_tweens = 255;
var tween_count: u8 = 0;
var active_tweens: [max_tweens]TweenAdapter = undefined;

pub fn init(_allocator: Allocator) void {
    allocator = _allocator;
}

pub fn deinit() void {
    for (0..tween_count) |i| {
        active_tweens[i].deinit(allocator);
    }
}

pub fn update(delta: f32) !void {
    for (0..tween_count) |i| {
        try active_tweens[i].update(delta);
    }
}

pub fn create(comptime T: type, source: *T, target: T, duration: f32) !void {
    if (tween_count == max_tweens) return error.OutOfMemory;

    var tween = try allocator.create(Tween(T));
    tween.* = Tween(T).init(
        source,
        target,
        duration
    );

    active_tweens[tween_count] = tween.getTweenAdapter();
    tween_count += 1;
}

const TweenAdapter = struct {
    tween: *anyopaque,
    updateFn: *const fn(*anyopaque, f32) anyerror!void,
    deinitFn: *const fn(*anyopaque, Allocator) void,

    fn update(self: *TweenAdapter, delta: f32) !void {
        try self.updateFn(self.tween, delta);
    }

    fn deinit(self: *TweenAdapter, _allocator: Allocator) void {
        self.deinitFn(self.tween, _allocator);
    }
};

fn Tween(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        .@"struct" => {
            if (T == Vector2 or T == Rectangle) {}
            else @compileError("Given type cannot be tweened.");
        },
        else => @compileError("Given type cannot be tweened."),
    }
    
    return struct {
        source: *T,
        target: T,
        duration: f32,
        elapsed: f32 = 0,

        const Self = @This();

        fn init(source: *T, target: T, duration: f32) Self {
            return .{
                .source = source,
                .target = target,
                .duration = duration
            };
        }

        fn deinit(_self: *anyopaque, _allocator: Allocator) void {
            const self: *Self = @alignCast(@ptrCast(_self));
            _allocator.destroy(self);
        }

        fn getTweenAdapter(self: *Self) TweenAdapter {
            return .{
                .tween = self,
                .updateFn = Self.update,
                .deinitFn = Self.deinit,
            };
        }

        pub fn update(_self: *anyopaque, delta: f32) !void {
            const self: *Self = @alignCast(@ptrCast(_self));
            self.elapsed += delta;

            switch (@typeInfo(T)) {
                .int,
                .float => {
                    self.source.* = std.math.lerp(
                        self.source.*,
                        self.target,
                        self.elapsed / self.duration
                    );
                },
                .@"struct" => {
                    switch (T) {
                        Vector2 => {
                            self.source.*.x = std.math.lerp(
                                self.source.x,
                                self.target.x,
                                self.elapsed / self.duration
                            );

                            self.source.*.x = std.math.lerp(
                                self.source.y,
                                self.target.y,
                                self.elapsed / self.duration
                            );
                        },
                        Rectangle => {
                            self.source.*.x = std.math.lerp(
                                self.source.x,
                                self.target.x,
                                self.elapsed / self.duration
                            );

                            self.source.*.y = std.math.lerp(
                                self.source.y,
                                self.target.y,
                                self.elapsed / self.duration
                            );

                            self.source.*.width = std.math.lerp(
                                self.source.width,
                                self.target.width,
                                self.elapsed / self.duration
                            );

                            self.source.*.height = std.math.lerp(
                                self.source.height,
                                self.target.height,
                                self.elapsed / self.duration
                            );
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }

            if (self.elapsed >= self.duration) {
                self.source.* = self.target;
            }
        }
    };
}
