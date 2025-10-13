const std = @import("std");
const rl = @import("raylib");
const lib = @import("../../lib.zig");
const game_state = lib.game.state;
const settings = lib.app.settings;
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

hitbox: Rectangle,
// TODO cache most recent collision to not have to ask the hash table every frame.

const Self = @This();

/// Checks in a hitbox adjusted tile field around the player for collisions.
/// Returns true if collision ocured, otherwise, false.
pub fn checkCollisionAtPos(self: *Self, pos: Vector2) bool {
    const x_range = std.math.clamp(
        @as(u8, @intFromFloat(self.hitbox.width / settings.tile_size)),
        1,
        std.math.maxInt(u8)
    );
    const y_range = std.math.clamp(
        @as(u8, @intFromFloat(self.hitbox.height / settings.tile_size)),
        1,
        std.math.maxInt(u8)
    );

    return checkCollisionAtPosManualSize(self, pos, x_range, y_range);
}

/// Checks in a given area of tiles around the player for collisions.
/// Returns true if collision ocured, otherwise, false.
pub fn checkCollisionAtPosManualSize(self: *Self, pos: Vector2, x_range: u8, y_range: u8) bool {
    const center_pos = pos.add(self.getCenter());
    const positioned_hitbox = Rectangle.init(
        self.hitbox.x + pos.x,
        self.hitbox.y + pos.y,
        self.hitbox.width,
        self.hitbox.height,
    );

    for (0..x_range * 2 + 1) |xo| {
        const x_offset = @as(i8, @intCast(xo)) - @as(i8, @intCast(x_range));
        for (0..y_range * 2 + 1) |yo| {
            const y_offset = @as(i8, @intCast(yo)) - @as(i8, @intCast(y_range));

            const offset_pos = center_pos.add(Vector2.scale(
                .{
                    .x = @floatFromInt(x_offset),
                    .y = @floatFromInt(y_offset),
                },
                settings.tile_size
            ));

            const collision_shape = game_state.map.collision_map.getCollisionAtPos(offset_pos) orelse continue;
            if (positioned_hitbox.checkCollision(collision_shape)) return true;
        }
    }
    return false;
}

/// Retuns as an offset from the position.
pub fn getCenter(self: Self) Vector2 {
    return .{
        .x = self.hitbox.width / 2 + self.hitbox.x,
        .y = self.hitbox.height / 2 + self.hitbox.y,
    };
}

pub fn getBottomOffset(self: Self) f32 {
    return self.hitbox.height + self.hitbox.y;
}
