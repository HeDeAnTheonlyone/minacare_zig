const std = @import("std");
const rl = @import("raylib");
const unpackParam = @import("signals.zig").CallbackCaster.packParam;
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

    pub fn draw(self: Self, position: rl.Vector2) void {
        rl.drawTextureRec(
            self.texture,
            self.frame_rect,
            position,
            rl.Color.white);
    }

    /// Adapter for the update function to work in a callback
    /// Requires `self: *AnimationPlayer` and `delta: f32`
    pub fn updateCallbackAdapter(ctx: *anyopaque, param: ?usize) DummyError!void {
        const self: *AnimationPlayer = @ptrCast(@alignCast(ctx));
        const delta: f32 = unpackParam(f32, param.?);

        update(self, delta);
    }

    /// The main update function that handles the whole process of this object 
    pub fn update(self: *Self, delta: f32) void {
        updateFrameTime(self, delta);
    }

    fn updateFrameTime(self: *Self, delta: f32) void {
        if (self.animations[self.current_animation].getFramesCount() == 1) return;
        if (self.paused) return;
        self.sub_frame_counter += 60 * delta;
        if (self.sub_frame_counter < self.frame_time) return;
        self.sub_frame_counter = 0;
        updateFrame(self);
    }

    fn updateFrame(self: *Self) void {
        const columns = @divFloor(self.texture.width, self.frame_width);
        const rows = @divFloor(self.texture.height, self.frame_height);

        const frame = self.animations[self.current_animation].start_frame + self.current_frame;

        const column = @mod(frame, columns);
        const row = @mod(@divFloor(frame, columns), rows);

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
    pos: Vector2 = .{.x = 0, .y = 0},
    motion: Vector2 = .{.x = 0, .y = 0},
    velocity: f32 = 0,
    acceleration: f32 = 0,
    max_speed: f32 = 0,
    stopping_distance: f32 = 0,

    const Self = @This();

    pub fn move(self: *Self, target_pos: Vector2, delta: f32) void {
        self.motion = Vector2.subtract(target_pos, self.pos);

        self.velocity =
            if (self.motion.length() > self.stopping_distance) std.math.clamp(
                self.velocity + self.acceleration * delta,
                0,
                self.max_speed * 0.1
            )
            else std.math.clamp(
                self.velocity - self.acceleration * 1.5 * delta,
                0,
                self.max_speed * 0.1
            );
        
        const lerp_amount = std.math.clamp(self.velocity / self.motion.length(), 0, 1);
        self.pos = Vector2.lerp(self.pos, target_pos, lerp_amount);
    }
};
