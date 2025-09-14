const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const settings = @import("settings.zig");
const event = @import("event.zig");
const drawer = @import("drawer.zig");

msg_queue: [max_msg]Message,
msg_count: u32,
msg_pointer: u32,
events: struct {
    on_popup: event.Dispatcher(void),
    on_close: event.Dispatcher(void),
},

const Self = @This();
pub const init = Self{
    .msg_queue = undefined,
    .msg_count = 0,
    .msg_pointer = 0,
    .events = .{
        .on_popup = .init,
        .on_close = .init,
    }
};
const max_msg = 255;

pub const Message = struct {
    text: [:0]const u8,
    // answers: [][]const u8,
};

pub fn update(self: *Self, _: f32) void {
    if (self.msg_count == 0) return;
    if (rl.isKeyReleased(.space)) {
        self.nextMessage();
    }
}

pub fn draw(self: *Self) !void {
    if (self.msg_count == 0) return;

    const rect = rl.Rectangle.init(
        50,
        @as(f32, @floatFromInt(settings.window_height)) * 0.7,
        @floatFromInt(settings.window_width - 100),
        @floatFromInt(@divFloor(settings.window_height, 4)),
    );
    drawer.drawRectAsIs(rect, .white);

    drawer.drawRectOutlineAsIs(rect.scaleCentered(0.9), 5, .red);

    rg.setStyle(.default, .{ .default = .text_size }, 24);
    _ = rg.label(rect.scaleCentered(0.9), self.getCurrentMessage()); 
}

pub fn enqueuMessageList(self: *Self, msgs: []const Message) !void {
    for (msgs) |msg| {
        try self.enqueueMessage(msg);
    }
}

pub fn enqueueMessage(self: *Self, msg: Message) !void {
    if (self.msg_count == max_msg) return error.OutOfMemory;

    self.msg_queue[self.msg_count] = msg;
    self.msg_count += 1;
    if (self.msg_count == 1) try self.popup();
}

fn getCurrentMessage(self: *Self) [:0]const u8 {
    return self.msg_queue[self.msg_pointer].text;
}

/// Moves to the next message and calls the close function when no messages are left.
fn nextMessage(self: *Self) !void {
    if (self.msg_pointer == self.msg_count) {
        try self.close();
        return "";
    }
    // const msg = self.msg_queue[self.msg_pointer];
    self.msg_pointer += 1;
    // return msg;
}

/// Makes the textbox appear
fn popup(self: *Self) !void {
    //TODO

    try self.events.on_popup.dispatch({});
}

/// Closes the textbox
fn close(self: *Self) !void {
    self.msg_count = 0;
    self.msg_pointer = 0;

    try self.events.on_close.dispatch({});
}
