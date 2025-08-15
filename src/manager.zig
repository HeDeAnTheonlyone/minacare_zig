const ArrayList = @import("std").ArrayList;
const signals = @import("signals.zig");

/// Calls the update function on every registered object and passes it the delta time
pub const UpdateManager = struct {
    update_list: ArrayList(signals.Callback),

    const Self = @This();

    pub fn addCallback(self: *Self, callback: signals.Callback) !void {
        try self.update_list.append(callback);
    }

    pub fn update(self: *Self, delta: f32) !void {
        for (self.update_list.items) |callback| {
            try callback.call(signals.CallbackCaster.packParam(delta));
        }
    }
};

pub const DrawManager = struct {
    update_list: ArrayList(signals.Callback),

    const Self = @This();

    pub fn addCallback(self: *Self, callback: signals.Callback) !void {
        try self.update_list.append(callback);
    }

    // pub fn removeCallback(self: *Self, callback: signals.Callback) !void {
    //     self.update_list
    // }

    pub fn draw(self: *Self) !void {
        for (self.update_list.items) |callback| {
            try callback.call(null);
        }
    }
};