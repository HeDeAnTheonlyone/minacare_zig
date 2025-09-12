const rl = @import("raylib");
const settings = @import("settings.zig");
const game_state = @import("game_state.zig");
const TileMap = @import("TileMap.zig");
const Character = @import("Character.zig");
const components = @import("components.zig");
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;
const Location = TileMap.Location;

pub const Cerber = struct {
    pub const vtable: Character.VTable = .{
        .updateVisuals = updateVisuals,
        .getInputVector = components.input.getInputVector,
    };

    fn updateVisuals(self: *Character) !void {
        const input_vec = self.vtable.getInputVector();

        if (@abs(input_vec.x) < @abs(input_vec.y)) {
            if (input_vec.y < 0) try self.animation.setAnimation("walk_up");
            if (input_vec.y > 0) try self.animation.setAnimation("walk_down");

            self.animation.setFlip(false);
        }
        
        else if (@abs(input_vec.x) > @abs(input_vec.y)) {
            try self.animation.setAnimation("walk_side");
            
            if (input_vec.x < 0) self.animation.setFlip(false)
            else if (input_vec .x > 0) self.animation.setFlip(true);
        }
    }

    pub fn spawn(spawn_location: Location) !Character {
        const animation = components.AnimationPlayer.init(
            &game_state.character_spritesheet,
            2,
            2,
            7
        );
        
        const collider = components.Collider{
            .hitbox = Rectangle.init(
                4,
                0,
                22,
                32,
            ),
        };

        const movement = components.Movement.init(
            blk: {
                    var pos: Vector2 =  spawn_location.asPos();
                    break :blk pos.add(collider.getCenter());
                },
            100,
        );

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
        try char.animation.addAnimation(.{ .name = "walk_side", .start_frame = 384, .end_frame = 384 });

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

    pub fn spawn(spawn_location: Location) !Character {
            const animation = components.AnimationPlayer.init(
                &game_state.character_spritesheet,
                1,
                1,
                7
            );
            
            const collider = components.Collider{
                .hitbox = Rectangle.init(
                    0,
                    3,
                    16,
                    13,
                ),
            };

            const movement = components.Movement.init(
                blk: {
                    var pos: Vector2 = spawn_location.asPos();
                    break :blk pos.add(collider.getCenter());
                },
                100,
            );

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
