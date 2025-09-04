const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig"); 
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;

const DummyError = error{};

pub const AnimationPlayer = struct {
    texture: rl.Texture,
    frame_rect: Rectangle = undefined,
    frame_width: i32,
    frame_height: i32,
    sub_frame_counter: f32 = 0,
    frame_time: f32 = 0,
    animations: [max_animations]Animation = undefined,
    current_frame: u16 = 0,
    animation_count: u8 = 0,
    current_animation: u8 = 0,
    h_flip: bool = false,
    looping: bool = true,
    paused: bool = false,

    const Self = @This();
    const max_animations = 64;

    pub const Animation = struct {
        start_frame: u16,
        end_frame: u16,

        /// Returns the total amount of frames for this animation
        pub fn getFramesCount(self: *Animation) u16 {
            return self.end_frame - self.start_frame + 1;
        }
    };

    pub fn init(texture: rl.Texture2D, frame_width: i32, frame_height: i32, frame_time: f32) Self {
        var obj = Self {
            .texture = texture,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .frame_time  = frame_time,
        };
        updateFrame(&obj);
        return obj;
    }

    pub fn deinit(self: *Self) void {
        rl.unloadTexture(self.texture);
    }

    pub fn draw(self: Self, pos: rl.Vector2) void {
        rl.drawTexturePro(
            self.texture,
            self.frame_rect,
            Rectangle.init(
                pos.x,
                pos.y,
                self.frame_rect.width * settings.getResolutionRatio(),
                self.frame_rect.height * settings.getResolutionRatio()
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

    fn updateFrameTime(self: *Self, delta: f32) void {
        if (self.animations[self.current_animation].getFramesCount() == 1) return;
        if (self.paused) return;
        if (self.frame_time < 1) return;
        self.sub_frame_counter += 60 * delta;
        if (self.sub_frame_counter < self.frame_time) return;
        self.sub_frame_counter = 0;
        updateFrame(self);
    }

    fn updateFrame(self: *Self) void {
        const columns = @divFloor(self.texture.width, self.frame_width);
        // const rows = @divFloor(self.texture.height, self.frame_height);

        const frame = self.animations[self.current_animation].start_frame + self.current_frame;

        const column = @mod(frame, columns);
        const row = @divFloor(frame, columns);

        self.frame_rect = Rectangle{
            .x = @floatFromInt(column * self.frame_width),
            .y = @floatFromInt(row * self.frame_height),
            .width = @floatFromInt(if (self.h_flip) -self.frame_width else self.frame_width),
            .height = @floatFromInt(self.frame_height),
        };

        self.current_frame += 1;
        const total_frames = self.animations[self.current_animation].getFramesCount();
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

    pub fn setAnimation(self: *Self, id: u8) !void {
        if (id == self.current_animation) return;
        if (id > self.animation_count - 1) return error.OutOfBounds;
        self.current_animation = id;
        self.current_frame = 0;
        self.sub_frame_counter = 0;
        updateFrame(self);
    }

    /// Sets and updates the animations frame
    pub fn setFrame(self: *Self, frame: u8) void {
        self.current_frame = frame;
        const total_frames = self.animations[self.current_animation].getFramesCount();
        if (self.current_frame >= total_frames) self.current_frame = 0;
        updateFrame(self);
    }

    pub fn getFrameRect(self: *const Self) Rectangle {
        return Rectangle.init(
            0,
            0,
            @floatFromInt(self.frame_width),
            @floatFromInt(self.frame_height),
        );
    }
};

pub const Movement = struct {
    pos: Vector2,
    motion: Vector2 = Vector2.splat(0),
    speed: f32,
    pos_changed_event: event.Dispatcher(Vector2) = .init,

    const Self = @This();

    pub fn init(pos: Vector2, speed: f32) Self {
        return .{
            .pos = pos,
            .speed = speed,
        };
    }

    pub fn getNextPos(self: *Self, input_vec: Vector2, delta: f32) Vector2 {
        const s = self.speed * delta * settings.getResolutionRatio();
        self.motion = input_vec.multiply(Vector2.splat(s));
        return self.pos.add(self.motion);
    }

    pub fn move(self: *Self, target_pos: Vector2, ) !void {
        try self.pos_changed_event.dispatch(target_pos);
        self.pos = target_pos;
    }

    /// Returns the position without the screen size compensation applied.
    pub fn getNativePos(self: *Self) Vector2 {
        return self.pos.scale(1 / settings.getResolutionRatio());
    }

    //TODO get center function
    // pub fn getCenter()

    // pub fn smooth_in_out_move(self: *Self, target_pos: Vector2, delta: f32) void {
    //     self.motion = Vector2.subtract(target_pos, self.pos);

    //     self.velocity =
    //         if (self.motion.length() > self.stopping_distance) std.math.clamp(
    //             self.velocity + self.acceleration * delta,
    //             0,
    //             self.max_speed * 0.1
    //         )
    //         else std.math.clamp(
    //             self.velocity - self.acceleration * 1.5 * delta,
    //             0,
    //             self.max_speed * 0.1
    //         );
        
    //     const lerp_amount = std.math.clamp(self.velocity / self.motion.length(), 0, 1);
    //     self.pos = Vector2.lerp(self.pos, target_pos, lerp_amount);
    // }
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

pub const Collider = struct {
    hitbox: Rectangle,
    // TODO abstract current_map later for multiple collision sources (ex.: entities)
    current_map: *TileMap.RuntimeMap.CollisionMap,
    // TODO make cache only work for collision map when other collisions sources get added
    last_coordinates: TileMap.Coordinates = undefined,
    last_collision_check: bool = undefined,

    const Self = @This();

    /// Checks in a 3x3 tile field around the player for collisions.
    /// Original position is needed without the screen size compensation applied.
    /// Returns true if collision occured, otherwise, false.
    pub fn checkCollisionAtPos(self: *Self, pos: Vector2) bool {
        const coords = TileMap.Coordinates.fromPosition(pos);
        if (coords.equals(self.last_coordinates)) return self.last_collision_check;
        self.last_coordinates = coords;
        
        const coord_offset: [9]TileMap.Coordinates = .{
            .{.x = -1, .y = -1},
            .{.x = 0, .y = -1},
            .{.x = 1, .y = -1},
            .{.x = -1, .y = 0},
            .{.x = 0, .y = 0},
            .{.x = 1, .y = 0},
            .{.x = -1, .y = 1},
            .{.x = 0, .y = 1},
            .{.x = 1, .y = 1},
        };

        const backup_x, const backup_y = .{self.hitbox.x, self.hitbox.y};
        defer self.hitbox.x, self.hitbox.y = .{backup_x, backup_y};
        try moveHitbox(self, pos);

        var is_colliding = false;
        for (coord_offset) |offset| {
            const offset_coords = coords.add(offset);
            const collision_shape = self.current_map.collision_shapes.get(offset_coords) orelse continue;
            is_colliding = is_colliding or self.isColliding(collision_shape);
        }
        
        self.last_collision_check = is_colliding;
        return is_colliding;
    }

    pub fn isColliding(self: *Self, collision_shape: Rectangle) bool {
        return self.hitbox.checkCollision(collision_shape);
    }

    pub fn moveHitbox(self_: *anyopaque, new_position: Vector2) DummyError!void {
        const self: *Self = @alignCast(@ptrCast(self_));

        std.debug.print("### MOVE HITBOX ###\n", .{});

        self.hitbox.x = new_position.x;
        self.hitbox.y = new_position.y;
    }
};
