const std = @import("std");
const signals = @import("signals.zig");

pub const CallbackDispatcher = struct {
    update_list: [max_updatables]signals.Callback = undefined,
    len: u8 = 0,

    const Self = @This();
    const max_updatables = 255;

    pub fn dispatch(self: *Self, delta: f32) !void {
        for (0..self.len) |index| {
            try self.update_list[index].call(signals.CallbackCaster.packParam(delta));
        }
    }

    pub fn add(self: *Self, callback: signals.Callback) !void {
        if (self.len == max_updatables) return error.OutOfMemory;
        self.update_list[self.len] = callback;
        self.len += 1;
    }

    pub fn remove(self: *Self, callback: signals.Callback) void {
        if (self.len == 0) return
        for (0..self.len) |index| {
            if (std.meta.eql(self.update_list[index], callback)) {
                self.update_list[index] = self.update_list[self.len - 1];
                self.len -= 1;
            }
        };
    } 
};