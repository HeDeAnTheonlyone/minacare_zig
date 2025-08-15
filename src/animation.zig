const std = @import("std");
const rl = @import("raylib");
const cfg = @import("config.zig").Config;
const unpackParam = @import("signals.zig").CallbackCaster.packParam;
const Rectangle = rl.Rectangle;

const NoError = error{};

pub const AnimationPlayer = struct {
    texture: rl.Texture2D,
    frame_rect: Rectangle = undefined,
    frame_width: i32,
    frame_height: i32,
    sub_frame_counter: f32 = 0,
    frame_time: u8 = 0,
    total_frames: u8 = 0,
    current_frame: u8 = 0,
    h_flip: bool = false,
    paused: bool = false,

    const Self = @This();

    pub fn init(texture: rl.Texture2D, frame_width: i32, frame_height: i32, frame_time: u8, total_frames: u8) Self {
        var obj = Self {
            .texture = texture,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .frame_time  = frame_time,
            .total_frames = total_frames,
        };
        obj.nextFrame();
        return obj;
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
    pub fn updateCallbackAdapter(ctx: *anyopaque, param: ?usize) NoError!void {
        const self: *AnimationPlayer = @ptrCast(@alignCast(ctx));
        const delta: f32 = unpackParam(f32, param.?);

        update(self, delta);
    }

    pub fn update(self: *Self, delta: f32) void {
        if (self.paused) return;
        self.sub_frame_counter += delta * cfg.target_fps;
        if (@as(u8, (@intFromFloat(self.sub_frame_counter))) < self.frame_time) return;
        self.sub_frame_counter = 0;
        nextFrame(self);
    }

    /// Sets and updates the animations frame
    pub fn setFrame(self: *Self, frame: u8) void {
        self.current_frame = frame;
        nextFrame(self);
    }

    fn nextFrame(self: *Self) void {
        const columns = @divFloor(self.texture.width, self.frame_width);
        const rows = @divFloor(self.texture.height, self.frame_height);

        const column = @mod(self.current_frame, columns);
        const row = @mod(@divFloor(self.current_frame, columns), rows);

        self.frame_rect = Rectangle{
            .x = @floatFromInt(column * self.frame_width),
            .y = @floatFromInt(row * self.frame_height),
            .width = @floatFromInt(if (self.h_flip) -self.frame_width else self.frame_width),
            .height = @floatFromInt(self.frame_height),
        };

        self.current_frame += 1;
        if (self.current_frame >= self.total_frames) self.current_frame = 0;
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