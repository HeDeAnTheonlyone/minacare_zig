const std = @import("std");

pub fn Callback(comptime param_type: type) type {
    return struct {
        func: *const fn(ctx: ?*anyopaque, args: param_type) anyerror!void,
        ctx: ?*anyopaque,

        const Self = @This();

        pub fn init(comptime ctx: anytype, comptime fn_name: []const u8) Self {
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
        callback_list: [max_callbacks]struct{callback: Callback(param_type), priority: i32}, // Implement the priority
        callback_count: u32,

        const Self = @This();
        pub const init = Self{.callback_list = undefined, .callback_count = 0};

        pub fn dispatch(self: *Self, args: param_type) anyerror!void {
            for (0..self.callback_count) |i| {
                try self.callback_list[i].callback.invoke(args);
            }
        }

        pub fn add(self: *Self, callback: Callback(param_type), priority: i32) !void {
            if (self.callback_count == max_callbacks) return error.OutOfMemory;
            
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
            if (self.callback_count == 0) return
            for (0..self.callback_count) |i| {
                if (
                    self.callback_list[i].callback.func == callback.func and
                    self.callback_list[i].callback.ctx == callback.ctx
                ) {
                    @memmove(
                        self.callback_list[i..self.callback_count],
                        self.callback_list[i + 1..self.callback_count + 1]
                    );
                    self.callback_count -= 1;
                }
            };
        }
    };
}
