const std = @import("std");

pub fn Callback(comptime param_type: type) type {
    return struct {
        func: *const fn(ctx: ?*anyopaque, args: param_type) anyerror!void,
        ctx: ?*anyopaque,

        const Self = @This();

        pub fn init(ctx: anytype, comptime fn_name: []const u8) Self {
            return switch (@typeInfo(@TypeOf(ctx))) {
                .pointer => |p| blk: {
                    const T = p.child;
                    if (T == type) @compileError("Types have to be passed directly.");
                    break :blk .{
                        .func = createPointerAdapterFn(T, fn_name),
                        .ctx = ctx,
                    };
                },
                .type => .{
                        .func = createTypeAdapterFn(ctx, fn_name),
                        .ctx = null,
                    },
                else => @compileError("Callback context has to be a pointer or type."),
            };
        }

        pub fn invoke(self: *Self, args: param_type) !void {
            try self.func(self.ctx, args);
        }

        fn createPointerAdapterFn(
            comptime T: type,
            comptime fn_name: []const u8
        ) fn(?*anyopaque, param_type) anyerror!void {
            return struct{
                fn adapter(ctx: ?*anyopaque, args: param_type) !void {
                    const f = @field(T, fn_name);
                    const obj: *T = @alignCast(@ptrCast(ctx.?));
                    const args_list = switch (@typeInfo(param_type)) {
                        .void => .{obj},
                        .array => .{obj} ++ args,
                        else => .{obj} ++ .{args},
                    };

                    try @call(
                        .auto,
                        f,
                        args_list,
                    );
                }
            }.adapter;
        }

        fn createTypeAdapterFn(
            comptime T: type,
            comptime fn_name: []const u8
        ) fn(?*anyopaque, param_type) anyerror!void {
            return struct{
                fn adapter(_: ?*anyopaque, args: param_type) !void {
                    const f = @field(T, fn_name);
                    const args_list = switch (@typeInfo(param_type)) {
                        .void => {
                            try f();
                            return;
                        },
                        .array => args,
                        else => .{args},
                    };

                    try @call(
                        .auto,
                        f,
                        args_list,
                    );
                }
            }.adapter;
        }
    };
}

pub fn Dispatcher(comptime param_type: type, comptime max_callbacks: u32) type {
    return struct {
        callback_list: [max_callbacks]struct{
            callback: Callback(param_type),
            priority: i32,
            to_remove: bool = false
        } = undefined,
        callback_count: u32,
        is_dispatching: bool = false,
        callbacks_to_remove: bool = false,

        const Self = @This();
        pub const is_dispatcher = {};
        pub const init = Self{.callback_list = undefined, .callback_count = 0};

        pub fn dispatch(self: *Self, args: param_type) anyerror!void {
            self.is_dispatching = true;
            for (0..self.callback_count) |i| {
                if (self.callback_list[i].to_remove) continue;
                try self.callback_list[i].callback.invoke(args);
            }
            self.is_dispatching = false;
            if (self.callbacks_to_remove) self.removeMarked();
        }

        pub fn add(self: *Self, callback: Callback(param_type), priority: i32) !void {
            if (self.callback_count == max_callbacks) return error.OutOfMemory;
            //TODO make safe for additions during dispatch.
            const index = for (0..self.callback_count) |i| {
                if (self.callback_list[i].priority < priority) {
                    @memmove(
                        self.callback_list[i + 1..self.callback_count + 1],
                        self.callback_list[i..self.callback_count]
                    );
                    break i;
                }
            }
            else self.callback_count;

            self.callback_list[index] = .{.callback = callback, .priority = priority};
            self.callback_count += 1;
        }

        pub fn remove(self: *Self, callback: Callback(param_type)) void {
            if (self.callback_count == 0) return;
            for (0..self.callback_count) |i| {
                if (
                    self.callback_list[i].callback.func == callback.func and
                    self.callback_list[i].callback.ctx == callback.ctx
                ) {
                    if (self.is_dispatching){
                        self.callback_list[i].to_remove = true;
                        self.callbacks_to_remove = true;
                    }
                    else self.removeAt(i);
                    break;
                }
            }
        }

        fn removeAt(self: *Self, index: usize) void {
            if (index < max_callbacks - 1 and index < self.callback_count - 1)
                @memmove(
                    self.callback_list[index..self.callback_count - 1],
                    self.callback_list[index + 1..self.callback_count]
                );
            self.callback_count -= 1;
        }

        fn removeMarked(self: *Self) void {
            var i: u32 = 0;
            while (i < self.callback_count) {
                if (self.callback_list[i].to_remove) {
                    self.removeAt(i);
                    continue;
                }
                i += 1;
            }
        }
    };
}
