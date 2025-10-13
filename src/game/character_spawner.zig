const rl = @import("raylib");
const lib = @import("../lib.zig");
const game = lib.game;
const settings = lib.app.settings;
const game_state = game.state;
const TileMap = game.TileMap;
const Character = game.Character;
const components = game.components;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;
const Location = TileMap.Location;

pub const Cerber = struct {
    pub const vtable: Character.VTable = .{
        .updateRotation = updateRotation,
        .getInputVector = components.input.getInputVector,
    };

    fn updateRotation(self: *Character) !void {
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
                5,
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

        try char.animation.addAnimationList(&.{
            .{ .name = "idle", .start_frame = 512, .end_frame = 512 },
            .{ .name = "walk_up", .start_frame = 1024, .end_frame = 1024 },
            .{ .name = "walk_down", .start_frame = 512, .end_frame = 512 },
            .{ .name = "walk_side", .start_frame = 1536, .end_frame = 1536 },
        });

        return char;
    }
};

pub const Cerby = struct {
    pub const vtable: Character.VTable = .{
        .updateRotation = updateRotation,
        .getInputVector = components.input.getInputVector,
    };

    fn updateRotation(self: *Character) !void {
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
                    2,
                    11,
                    12,
                    5,
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

            try char.animation.addAnimationList(&.{
                .{ .name = "idle", .start_frame = 0, .end_frame = 7 },
                .{ .name = "walk", .start_frame = 9, .end_frame = 16 },
            });

            return char;
    }
};
