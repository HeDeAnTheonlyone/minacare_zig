const rl = @import("raylib");
const game_state = @import("game_state.zig");
const Character = @import("Character.zig");
const components = @import("components.zig");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

pub const Cerber = struct {
    pub const vtable: Character.VTable = .{
        .updateVisuals = updateVisuals,
        .getInputVector = components.input.getInputVector,
    };

    fn updateVisuals(self: *Character) !void {
        const input_vec = self.vtable.getInputVector();
        if (input_vec.x < 0) self.animation.h_flip = false
        else if (input_vec .x > 0) self.animation.h_flip = true;

        if (input_vec.x > input_vec.y) {
            if (input_vec.y < 0) try self.animation.setAnimation("walk_up");
            if (input_vec.y > 0) try self.animation.setAnimation("walk_down");
        }
        else if (input_vec.x < input_vec.y) try self.animation.setAnimation("walk_side");
    }

    pub fn spawn(spawn_pos: Vector2) !Character {
        const animation = components.AnimationPlayer.init(
            game_state.character_spritesheet,
            2,
            2,
            7
        );

        const movement = components.Movement.init(
            spawn_pos,
            100,
        );
        
        const collider = components.Collider{
            .hitbox = Rectangle.init(
                6,
                0,
                32 - 12,
                32,
            ),
        };

        var char = Character{
            .animation = animation,
            .movement = movement,
            .collider = collider,
            .name = "cerber",
            .vtable = &vtable,
        };

        try char.animation.addAnimation(.{ .name = "idle", .start_frame = 128, .end_frame = 128 });
        try char.animation.addAnimation(.{ .name = "walk_up", .start_frame = 256, .end_frame = 256 });
        try char.animation.addAnimation(.{ .name = "walk_down", .start_frame = 128, .end_frame = 128 });
        try char.animation.addAnimation(.{ .name = "walk_side", .start_frame = 128, .end_frame = 128 });

        return char;
    }
};

pub const Cerby = struct {
    pub const vtable: Character.VTable = .{
        .updateVisuals = updateVisuals,
        .getInputVector = components.input.getInputVector,
    };

    fn updateVisuals(self: *Character) !void {
        const input_vec = self.vtable.getInputVector();
        if (input_vec.x < 0) self.animation.h_flip = false
        else if (input_vec .x > 0) self.animation.h_flip = true;

        if (input_vec.length() == 0) try self.animation.setAnimation("idle")
        else try self.animation.setAnimation("walk");
    }

    pub fn spawn(spawn_pos: Vector2) !Character {
            const animation = components.AnimationPlayer.init(
                game_state.character_spritesheet,
                1,
                1,
                7
            );

            const movement = components.Movement.init(
                spawn_pos,
                100,
            );
            
            const collider = components.Collider{
                .hitbox = Rectangle.init(
                    0,
                    3,
                    16,
                    13,
                ),
            };

            var char = Character{
                .animation = animation,
                .movement = movement,
                .collider = collider,
                .name = "cerby",
                .vtable = &vtable,
            };

            try char.animation.addAnimation(.{ .name = "idle", .start_frame = 0, .end_frame = 7 });
            try char.animation.addAnimation(.{ .name = "walk", .start_frame = 9, .end_frame = 16 });

            return char;
    }
};
