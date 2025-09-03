const std = @import("std");

pub fn CallbackFn(param_type: type) type {
    return *const fn(ctx: *anyopaque, param: param_type) anyerror!void;
}
    
pub fn Callback(param_type: type) type {
    return struct {
        func: CallbackFn(param_type),
        ctx: *anyopaque,

        const Self = @This();

        pub fn call(self: *const Self, param: param_type) !void {
            try self.func(self.ctx, param);
        }
    };
}

pub fn Dispatcher(param_type: type) type {
    return struct {
        callback_list: [max_callbacks]Callback(param_type),
        callback_count: u8,

        const Self = @This();
        pub const init = Self{.callback_list = undefined, .callback_count = 0};
        const max_callbacks = 255;

        pub fn dispatch(self: *Self, param: param_type) anyerror!void {
            for (0..self.callback_count) |i| {
                try self.callback_list[i].call(param);
            }
        }

        pub fn add(self: *Self, callback: Callback(param_type)) anyerror!void {
            if (self.callback_count == max_callbacks) return error.MaxCallbacksAlreadyReached;
            self.callback_list[self.callback_count] = callback;
            self.callback_count += 1;
        }

        pub fn remove(self: *Self, callback: Callback(param_type)) void {
            if (self.callback_count == 0) return
            for (0..self.callback_count) |i| {
                if (std.meta.eql(self.callback_list[i], callback)) {
                    self.callback_list[i] = self.callback_list[self.callback_count - 1];
                    self.callback_count -= 1;
                }
            };
        } 
    };
}
