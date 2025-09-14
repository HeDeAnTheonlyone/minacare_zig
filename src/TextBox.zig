const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const settings = @import("settings.zig");
const event = @import("event.zig");
const drawer = @import("drawer.zig");

queue: [max_messages]Message,
message_count: u32,
events: struct {
    on_popup: event.Dispatcher(void),
    on_close: event.Dispatcher(void),
},

const Self = @This();
pub const init = Self{
    .queue = undefined,
    .message_count = 0,
    .events = .{
        .on_popup = .init,
        .on_close = .init,
    }
};
const max_messages = 255;

pub const Message = struct {
    text: []const u8,
    // answers: [][]const u8,
};

pub fn update(self: *Self, delta: f32) void {
    _ = delta;
    if (self.message_count == 0) return;
}

pub fn draw(self: *Self) !void {
    _ = self;
    rl.drawRectangle(
        50,
        @intFromFloat(@as(f32, @floatFromInt(settings.window_height)) * 0.7),
        settings.window_width - 100,
        @divFloor(settings.window_height, 4),
        .white,
    );
}

pub fn enqueuMessageList(self: *Self, msgs: []const Message) !void {
    for (msgs) |msg| {
        self.enqueueMessage(msg);
    }
}

pub fn enqueueMessage(self: *Self, msg: Message) !void {
    if (self.message_count == max_messages) resume error.OutOfMemory;

    self.queue[self.message_count] = msg;
}

// fn readMessage(self: *Self) void {
//     self.message_count
// }

/// Makes the textbox appear
fn popup(self: *Self) void {
    //TODO

    self.events.on_popup.dispatch(void);
}

/// Closes the textbox
fn close(self: *Self) void {
    //TODO

    self.events.on_close.dispatch(void);
}
