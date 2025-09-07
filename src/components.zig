const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const debug = @import("debug.zig");
const game_state = @import("game_state.zig");
const event = @import("event.zig");
const drawer = @import("drawer.zig");
const TileMap = @import("TileMap.zig");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

const DummyError = error{};

pub const AnimationPlayer = struct {
    texture: rl.Texture,
    frame_rect: Rectangle = undefined,
    // frame_width: i32,
    // frame_height: i32,
    v_tiles: u8,
    h_tiles: u8,
    sub_frame_counter: f32 = 0,
    frame_time: f32 = 0,
    animations: [max_animations]Animation = undefined,
    current_frame: u16 = 0,
    animation_count: u8 = 0,
    current_animation: *Animation = undefined,
    h_flip: bool = false,
    looping: bool = true,
    paused: bool = false,

    const Self = @This();
    const max_animations = 32;

    pub const Animation = struct {
        name: []const u8,
        start_frame: u16,
        end_frame: u16,

        /// Returns the total amount of frames for this animation
        pub fn getFrameCount(self: *Animation) u16 {
            return self.end_frame - self.start_frame + 1;
        }
    };

    pub fn init(texture: rl.Texture2D, v_tiles: u8, h_tiles: u8, frame_time: f32) Self {
        var obj = Self {
            .texture = texture,
            .v_tiles = v_tiles,
            .h_tiles = h_tiles,
            .frame_time  = frame_time,
        };
        updateFrame(&obj);
        return obj;
    }

    pub fn draw(self: Self, pos: rl.Vector2) void {
        drawer.drawTexturePro(
            self.texture,
            self.frame_rect,
            Rectangle.init(
                pos.x,
                pos.y,
                self.frame_rect.width,
                self.frame_rect.height
            ),
            Vector2.zero(),
            0,
            rl.Color.white);
    }

    /// The main update function that handles the whole process of this object 
    pub fn update(self_: *anyopaque, delta: f32) void {
        const self: *Self = @alignCast(@ptrCast(self_));

        updateFrameTime(self, delta);
    }

    pub fn getFrameWidth(self: *Self) i32 {
        return self.v_tiles * settings.tile_size;
    }

    pub fn getFrameHeight(self: *Self) i32 {
        return self.h_tiles * settings.tile_size;
    }

    fn updateFrameTime(self: *Self, delta: f32) void {
        if (self.current_animation.getFrameCount() == 1) return;
        if (self.paused) return;
        if (self.frame_time < 1) return;

        const base_framerate = 60;
        self.sub_frame_counter += base_framerate * delta;
        if (self.sub_frame_counter < self.frame_time) return;
        self.sub_frame_counter = 0;
        
        updateFrame(self);
    }

    fn updateFrame(self: *Self) void {
        const columns = @divFloor(self.texture.width, self.getFrameWidth());
        const frame = self.current_animation.start_frame + self.current_frame;

        const column = @mod(frame, columns);
        const row = @divFloor(frame, columns);

        self.frame_rect = Rectangle{
            .x = @floatFromInt(column * self.getFrameWidth()),
            .y = @floatFromInt(row * self.getFrameHeight()),
            .width = @floatFromInt(if (self.h_flip) -self.getFrameWidth() else self.getFrameWidth()),
            .height = @floatFromInt(self.getFrameHeight()),
        };

        self.current_frame += 1;
        const total_frames = self.current_animation.getFrameCount();
        if (self.current_frame >= total_frames) {
            if (self.looping) self.current_frame = 0
            else self.current_frame = total_frames;
        }
    }

    pub fn addAnimation(self: *Self, anim: Animation) !void {
        if (self.animation_count == max_animations) return error.OutOfMemory;
        
        self.animations[self.animation_count] = anim;
        self.animation_count += 1;
    }

    pub fn setAnimation(self: *Self, name: []const u8) !void { 
        if (self.animation_count == 0) return error.EmptyAnimationList;
        if (std.mem.eql(u8, name, self.current_animation.name)) return;
        self.current_animation = blk: {
            for (self.animations, 0..) |anim, i| {
                if (std.mem.eql(u8, anim.name, name))
                    break :blk &self.animations[i];
            }
            return error.NoMatchingAnimation;
        };
        self.current_frame = 0;
        self.sub_frame_counter = 0;
        updateFrame(self);
    }

    /// Sets and updates the animations frame
    pub fn setFrame(self: *Self, frame: u8) void {
        self.current_frame = frame;
        const total_frames = self.animations[self.current_animation].getFrameCount();
        if (self.current_frame >= total_frames) self.current_frame = 0;
        updateFrame(self);
    }

    pub fn getFrameRect(self: *const Self) Rectangle {
        return Rectangle.init(
            0,
            0,
            @floatFromInt(self.getFrameWidth()),
            @floatFromInt(self.getFrameHeight()),
        );
    }

    /// Retuns as an offset and size from the position
    pub fn getCenter(self: *Self) Vector2 {
        return .{
            .x = @floatFromInt(@divFloor(self.getFrameWidth(), 2)),
            .y = @floatFromInt(@divFloor(self.getFrameHeight(), 2)),
        };
    }
};

pub const Movement = struct {
    pos: Vector2,
    speed: f32,
    pos_changed_event: event.Dispatcher(Vector2) = .init,

    const Self = @This();

    pub fn init(pos: Vector2, speed: f32) Self {
        return .{
            .pos = pos,
            .speed = speed,
        };
    }

    pub fn getMotion(self: *Self, input_vec: Vector2, delta: f32) Vector2 {
        const s = self.speed * delta;
        return input_vec.scale(s);
    }

    pub fn move(self: *Self, target_pos: Vector2, ) !void {
        try self.pos_changed_event.dispatch(target_pos);
        self.pos = target_pos;
    }
};

pub const input = struct {
    /// Returns a normalized vector that represents the input direction.
    pub fn getInputVector() rl.Vector2 {
        const v = @as(i8, @intFromBool(rl.isKeyDown(.s))) - @as(i8, @intFromBool(rl.isKeyDown(.w)));
        const h = @as(i8, @intFromBool(rl.isKeyDown(.d))) - @as(i8,@intFromBool(rl.isKeyDown(.a)));

        const vec = rl.Vector2{.x = @floatFromInt(h), .y = @floatFromInt(v)};
        return vec.normalize();
    }
};

/// Defines the collision shape of an object and handles the collision checks.
/// The collider is defined relative in the frame.
/// It is assumed that (0, 0) of the frame is the current position of the object
pub const Collider = struct {
    hitbox: Rectangle,

    const Self = @This();

    /// Checks in a hitbox adjusted tile field around the player for collisions.
    /// Returns true if collision ocured, otherwise, false.
    pub fn checkCollisionAtPos(self: *Self, pos: Vector2) bool {
        const positioned_hitbox = Rectangle.init(
            self.hitbox.x + pos.x,
            self.hitbox.y + pos.y,
            self.hitbox.width,
            self.hitbox.height,
        );

        const center_pos = pos.add(self.getCenter());
        const x_col_range = std.math.clamp(
            @as(u8, @intFromFloat(self.hitbox.width / settings.tile_size)),
            1,
            std.math.maxInt(u8)
        );
        const y_col_range = std.math.clamp(
            @as(u8, @intFromFloat(self.hitbox.height / settings.tile_size)),
            1,
            std.math.maxInt(u8)
        );
        
        var is_colliding = false;
        for (0..x_col_range * 2 + 1) |xo| {
            const x_offset = @as(i8, @intCast(xo)) - @as(i8, @intCast(x_col_range));
            for (0..y_col_range * 2 + 1) |yo| {
                const y_offset = @as(i8, @intCast(yo)) - @as(i8, @intCast(y_col_range));

                const offset_pos = center_pos.add(Vector2.scale(
                    .{
                        .x = @floatFromInt(x_offset),
                        .y = @floatFromInt(y_offset),
                    },
                    settings.tile_size
                ));

                const collision_shape = game_state.map.getTileCollision(offset_pos) orelse continue;
                is_colliding = is_colliding or positioned_hitbox.checkCollision(collision_shape);
            }
        }
        
        return is_colliding;
    }

    /// Retuns as an offset and size from the position.
    pub fn getCenter(self: *Self) Vector2 {
        return .{
            .x = self.hitbox.width / 2 + self.hitbox.x,
            .y = self.hitbox.height / 2 + self.hitbox.y,
        };
    }
};
