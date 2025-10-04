const std = @import("std");
const rl = @import("raylib");
const lib = @import("../../lib.zig");
const settings = lib.app.settings;
const drawer = lib.util.drawer;
const Texture2D = rl.Texture2D;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

texture: *Texture2D,
frame_rect: Rectangle = undefined,
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

const Animation = struct {
    name: []const u8,
    start_frame: u16,
    end_frame: u16,

    /// Returns the total amount of frames for this animation
    pub fn getFrameCount(self: *Animation) u16 {
        return self.end_frame - self.start_frame + 1;
    }
};

pub fn init(texture: *rl.Texture2D, v_tiles: u8, h_tiles: u8, frame_time: f32) Self {
    return .{
        .texture = texture,
        .v_tiles = v_tiles,
        .h_tiles = h_tiles,
        .frame_time  = frame_time,
    };
}

pub fn draw(self: Self, pos: rl.Vector2) void {
    drawer.drawTexturePro(
        self.texture.*,
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
pub fn update(self: *Self, delta: f32) void {
    updateFrameTime(self, delta);
}

pub fn getFrameWidth(self: *Self) i32 {
    return self.v_tiles * settings.tile_size;
}

pub fn getFrameHeight(self: *Self) i32 {
    return self.h_tiles * settings.tile_size;
}

fn updateFrameTime(self: *Self, delta: f32) void {
    if (
        self.current_animation.getFrameCount() == 1 or
        self.paused or
        self.frame_time < 1
    ) return;

    const base_framerate = 60;
    self.sub_frame_counter += base_framerate * delta;
    if (self.sub_frame_counter < self.frame_time) return;
    self.sub_frame_counter = 0;
    
    updateFrame(self);
}

fn updateFrame(self: *Self) void {
    // TODO make this precompute and then store it somewhere global
    const columns = @divFloor(self.texture.width, settings.tile_size);
    const frame = self.current_animation.start_frame + self.current_frame;

    const column = @mod(frame, columns);
    const row = @divFloor(frame, columns);

    self.frame_rect = Rectangle{
        .x = @floatFromInt(column * self.getFrameWidth()),
        .y = @floatFromInt(row * settings.tile_size),
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

// TODO Maybe make this more performant if neccessary
pub fn addAnimationList(self: *Self, anims: []const Animation) !void {
    for (anims) |anim| {
        try self.addAnimation(anim);
    }
}

pub fn addAnimation(self: *Self, anim: Animation) !void {
    if (self.animation_count == max_animations) return error.OutOfMemory;
    
    for (self.animations) |a| {
        if (std.mem.eql(u8, a.name, anim.name))
            return error.AnimationAlreadyExists;
    }

    self.animations[self.animation_count] = anim;
    self.animation_count += 1;
    if (self.animation_count == 1) {
        self.current_animation = &self.animations[0];
        self.updateFrame();
    }
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
    self.updateFrame();
}

/// Sets and updates the animations frame
pub fn setFrame(self: *Self, frame: u8) void {
    self.current_frame = frame;
    const total_frames = self.animations[self.current_animation].getFrameCount();
    if (self.current_frame >= total_frames) self.current_frame = 0;
    self.updateFrame();
}

pub fn setFlip(self: *Self, is_flipped: bool) void {
    if (is_flipped == self.h_flip) return;
    self.h_flip = is_flipped;
    self.updateFrame();
}

pub fn getFrameRect(self: *const Self) Rectangle {
    return Rectangle.init(
        0,
        0,
        @floatFromInt(self.getFrameWidth()),
        @floatFromInt(self.getFrameHeight()),
    );
}

/// Retuns as an offset from the position
pub fn getCenter(self: *Self) Vector2 {
    return .{
        .x = @floatFromInt(@divFloor(self.getFrameWidth(), 2)),
        .y = @floatFromInt(@divFloor(self.getFrameHeight(), 2)),
    };
}