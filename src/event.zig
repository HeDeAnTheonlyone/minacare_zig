const std = @import("std");

pub fn CallbackFn(comptime param_type: type) type {
    return *const fn(ctx: *anyopaque, param: param_type) anyerror!void;
}
    
pub fn Callback(comptime param_type: type) type {
    return struct {
        func: CallbackFn(param_type),
        ctx: *anyopaque,

        const Self = @This();

        pub fn invoke(self: *const Self, param: param_type) !void {
            try self.func(self.ctx, param);
        }
    };
}

pub fn createUpdateCallbackAdapter(T: type) fn(*anyopaque, f32) anyerror!void {
    return struct{
        fn adapter(obj_: *anyopaque, delta: f32) !void {
            const obj: *T = @alignCast(@ptrCast(obj_));
            try obj.update(delta);
        }
    }.adapter;
}

pub fn createDrawCallbackAdapter(T: type) fn(*anyopaque, void) anyerror!void {
    return struct{
        fn adapter(obj_: *anyopaque, _: void) !void {
            const obj: *T = @alignCast(@ptrCast(obj_));
            obj.draw();
        }
    }.adapter;
}

pub fn Dispatcher(comptime param_type: type) type {
    return struct {
        callback_list: [max_callbacks]Callback(param_type),
        callback_count: u8,

        const Self = @This();
        const max_callbacks = 128;
        pub const init = Self{.callback_list = undefined, .callback_count = 0};

        pub fn dispatch(self: *Self, param: param_type) anyerror!void {
            for (0..self.callback_count) |i| {
                try self.callback_list[i].invoke(param);
            }
        }

        pub fn add(self: *Self, callback: Callback(param_type)) anyerror!void {
            if (self.callback_count == max_callbacks) return error.OutOfMemory;
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
