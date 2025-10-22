const std = @import("std");
const rl = @import("raylib");
pub const lib = @import("../lib.zig");
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

const TimeSource = enum{
    global,
    game,
};

pub fn Tween(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        .@"struct" => {
            if (T == Vector2 or T == Rectangle) {}
            else @compileError("Given type cannot be tweened.");
        },
        else => @compileError("Given type cannot be tweened."),
    }
    
    return struct {
        allocator: Allocator,
        source: *T,
        begin: T,
        target: T,
        end_timestamp: f32 = 0,
        time_source: TimeSource,
        events: struct {
            on_finished: lib.util.event.Dispatcher(void, 1) = .init,
        } = .{},

        const Self = @This();

        /// The used allocator must have a longer lifetime than the tween.
        /// Once the Tween finishes it will free itself and any references will become dangling pointers.
        pub fn init(allocator: Allocator, source: *T, target: T, duration: f32, time_source: TimeSource) !*Self {
            const tween = try allocator.create(Self);
            const counter = getCounterValue(time_source);

            tween.* = Self{
                .allocator = allocator,
                .source = source,
                .begin = source.*,
                .target = target,
                .end_timestamp = counter + duration,
                .time_source = time_source,
            };
            switch (time_source) {
                .game => try lib.game.state.events.on_update.add(
                    .init(
                        tween,
                        "update"
                    ),
                    -100,
                ),
                .global => try lib.app.state.events.on_global_update.add(
                    .init(
                        tween,
                        "update"
                    ),
                    -100,
                )
            }
            return tween;
        }

        fn deinit(self: *Self) void {
            switch (self.time_source) {
                .game => lib.game.state.events.on_update.remove(
                    .init(
                        self,
                        "update"
                    ),
                ),
                .global => lib.app.state.events.on_global_update.remove(
                    .init(
                        self,
                        "update"
                    ),
                )
            }
            self.allocator.destroy(self);
        }

        /// Retrieves the correct counter based on the choosen time source.
        fn getCounterValue(time_source: TimeSource) f32 {
            return switch (time_source) {
                .game => lib.game.state.counter,
                .global => lib.app.state.counter,
            };
        }

        /// Updates the tween. Returns true if still running or false if finished.
        pub fn update(self: *Self, _: f32) !void {
            const counter = getCounterValue(self.time_source);
            const factor = counter / self.end_timestamp;
            switch (@typeInfo(T)) {
                .int,
                .float => {
                    self.source.* = std.math.lerp(
                        self.begin,
                        self.target,
                        factor
                    );
                },
                .@"struct" => {
                    switch (T) {
                        Vector2 => {
                            self.source.*.x = std.math.lerp(
                                self.begin.x,
                                self.target.x,
                                factor
                            );

                            self.source.*.y = std.math.lerp(
                                self.begin.y,
                                self.target.y,
                                factor
                            );
                        },
                        Rectangle => {
                            self.source.*.x = std.math.lerp(
                                self.begin.x,
                                self.target.x,
                                factor
                            );

                            self.source.*.y = std.math.lerp(
                                self.begin.y,
                                self.target.y,
                                factor
                            );

                            self.source.*.width = std.math.lerp(
                                self.begin.width,
                                self.target.width,
                                factor
                            );

                            self.source.*.height = std.math.lerp(
                                self.begin.height,
                                self.target.height,
                                factor
                            );
                        },
                        else => unreachable,
                    }
                },
                else => unreachable,
            }

            if (counter >= self.end_timestamp) {
                self.source.* = self.target;
                try self.events.on_finished.dispatch({});
                self.deinit();
            }
        }
    };
}
