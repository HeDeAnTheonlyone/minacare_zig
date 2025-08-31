const std = @import("std");
const signals = @import("signals.zig");

pub const CallbackDispatcher = struct {
    callback_list: [max_callbacks]signals.Callback = undefined,
    len: u8 = 0,

    const Self = @This();
    const max_callbacks = 255;

    pub fn dispatch(self: *Self, delta: f32) !void {
        for (0..self.len) |i| {
            try self.callback_list[i].call(signals.CallbackCaster.packParam(delta));
        }
    }

    pub fn add(self: *Self, callback: signals.Callback) !void {
        if (self.len == max_callbacks) return error.OutOfMemory;
        self.callback_list[self.len] = callback;
        self.len += 1;
    }

    pub fn remove(self: *Self, callback: signals.Callback) void {
        if (self.len == 0) return
        for (0..self.len) |i| {
            if (std.meta.eql(self.callback_list[i], callback)) {
                self.callback_list[i] = self.callback_list[self.len - 1];
                self.len -= 1;
            }
        };
    } 
};