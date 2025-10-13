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

pub fn update() !void {
    for (0..tween_count) |i| {
        if (!try active_tweens[i].update())
            destroy(i, allocator);
    }
}

/// Creates a new tween and puts it in the tween list.
/// The underlying tween gets allocated and automatically freed when finished.
/// `counter_ref` is the counter that gets used to measure the passing of time (can be game time, app time, or something else).
pub fn create(comptime T: type, source: *T, target: T, duration: f32, counter_ref: *f32) !*Tween(T) {
    if (tween_count == max_tweens) return error.OutOfMemory;

    var tween = try allocator.create(Tween(T));
    tween.* = Tween(T).init(
        source,
        target,
        counter_ref.* + duration,
        counter_ref,
    );

    active_tweens[tween_count] = tween.getTweenAdapter();
    tween_count += 1;
    return tween;
}

fn destroy(index: usize, _allocator: Allocator) void {
    active_tweens[index].deinit(_allocator);
    active_tweens[index] = active_tweens[tween_count - 1];
    tween_count -= 1;
}

const TweenAdapter = struct {
    tween: *anyopaque,
    updateFn: *const fn(*anyopaque) anyerror!bool,
    deinitFn: *const fn(*anyopaque, Allocator) void,

    /// Updates the underlying tween and returns its continuation state.
    fn update(self: *TweenAdapter) !bool {
        return try self.updateFn(self.tween);
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
        end_timestamp: f32,
        counter_ref: *f32,
        events: struct {
            on_finished: lib.util.event.Dispatcher(void, 1)
        },

        const Self = @This();

        fn init(source: *T, target: T, end_timestamp: f32, counter_ref: *f32) Self {
            std.debug.print("{d} - {d}\n", .{counter_ref.*, end_timestamp});
            return .{
                .source = source,
                .target = target,
                .end_timestamp = end_timestamp,
                .counter_ref = counter_ref,
                .events = .{
                    .on_finished = .init,
                },
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

        /// Updates the tween. Returns true if still running or false if finished.
        pub fn update(_self: *anyopaque) !bool {
            const self: *Self = @alignCast(@ptrCast(_self));
            const factor = self.counter_ref.* / self.end_timestamp;
            switch (@typeInfo(T)) {
                .int,
                .float => {
                    self.source.* = std.math.lerp(
                        self.source.*,
                        self.target,
                        factor
                    );
                },
                .@"struct" => {
                    switch (T) {
                        Vector2 => {
                            self.source.*.x = std.math.lerp(
                                self.source.x,
                                self.target.x,
                                factor
                            );

                            self.source.*.y = std.math.lerp(
                                self.source.y,
                                self.target.y,
                                factor
                            );
                        },
                        Rectangle => {
                            self.source.*.x = std.math.lerp(
                                self.source.x,
                                self.target.x,
                                factor
                            );

                            self.source.*.y = std.math.lerp(
                                self.source.y,
                                self.target.y,
                                factor
                            );

                            self.source.*.width = std.math.lerp(
                                self.source.width,
                                self.target.width,
                                factor
                            );

                            self.source.*.height = std.math.lerp(
                                self.source.height,
                                self.target.height,
                                factor
                            );
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }

            if (self.counter_ref.* >= self.end_timestamp) {
                self.source.* = self.target;
                try self.events.on_finished.dispatch({});
                return false;
            }
            return true;
        }
    };
}
