const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const game_state = @import("game_state.zig");
const debug = @import("debug.zig");
const settings = @import("settings.zig");
const event = @import("event.zig");
const drawer = @import("drawer.zig");
const translation = @import("translation.zig");
const Translatable = translation.Translatable;

msg_queue: [max_msg]Message,
displayed_chars: u32 = 0,
delay_counter: f32 = 0,
// TODO make this configurable
display_delay: f32,
msg_count: u8 = 0,
msg_pointer: u8 = 0,
current_msg_text: [4096]u8,
events: struct {
    on_popup: event.Dispatcher(void,8),
    on_close: event.Dispatcher(void, 8),
},

const Self = @This();
pub const init = Self{
    .msg_queue = undefined,
    .display_delay = 0.02,
    .current_msg_text = undefined,
    .events = .{
        .on_popup = .init,
        .on_close = .init,
    }
};
const max_msg = 255;

const Message = struct {
    text: Translatable,
    // answers: [][]const u8,
};

pub fn update(self: *Self, delta: f32) !void {
    if (self.msg_count == 0) return;
    
    // TODO Make this configurable
    if (rl.isKeyReleased(.space)) {
        try self.nextMessage();
    }

    if (self.displayed_chars < self.msg_queue[self.msg_pointer].text.translate().len) {
        self.delay_counter += delta;
        if (self.delay_counter >= self.display_delay) {
            self.delay_counter = 0;
            self.displayed_chars += 1;
        }
    }
}

pub fn draw(self: *Self) !void {
    if (self.msg_count == 0) return;

    const rect = rl.Rectangle.init(
        50,
        @as(f32, @floatFromInt(settings.render_height)) * 0.7,
        @floatFromInt(settings.render_width - 100),
        @floatFromInt(@divFloor(settings.render_height, 4)),
    );
    rl.drawRectangleRounded(rect, 0.2, 5, .white);

    rg.setStyle(.default, .{ .default = .text_size }, 32);
    rg.setStyle(.label, .{ .control = .text_padding }, 40);
    rg.setStyle(.default, .{ .default = .text_alignment_vertical }, 0);
    rg.setStyle(.default, .{ .control = .text_alignment }, 0);
    rg.setStyle(.default, .{ .default = .text_line_spacing }, 40);
    _ = rg.label(rect, self.getCurrentMessage()); 
}

pub fn enqueuMessageList(self: *Self, msgs: []const Message) !void {
    for (msgs) |msg| {
        try self.enqueueMessage(msg);
    }
}

pub fn enqueueMessage(self: *Self, msg: Message) !void {
    if (self.msg_count == max_msg) return error.OutOfMemory;
    if (msg.text.translate().len >= self.current_msg_text.len) return error.MessageTextTooLong;

    self.msg_queue[self.msg_count] = msg;
    self.msg_count += 1;
    if (self.msg_count == 1) try self.popup();
}

fn getCurrentMessage(self: *Self) [:0]const u8 {
    const msg = self.msg_queue[self.msg_pointer];
    std.mem.copyForwards(u8, &self.current_msg_text, msg.text.translate());
    self.current_msg_text[self.displayed_chars] = 0;
    return self.current_msg_text[0..self.displayed_chars:0];
}

/// Moves to the next message and calls the close function when no messages are left.
fn nextMessage(self: *Self) !void {
    self.msg_pointer += 1;

    self.displayed_chars = 0;
    self.delay_counter = 0;

    if (self.msg_pointer == self.msg_count) try self.close();
}

/// Makes the textbox appear
fn popup(self: *Self) !void {
    try self.events.on_popup.dispatch({});
}

/// Closes the textbox
fn close(self: *Self) !void {
    self.msg_count = 0;
    self.msg_pointer = 0;

    try self.events.on_close.dispatch({});
}
