const std =  @import("std");

/// file name is without the extension.
/// data is expected to have a `getSaveable()` function.
pub fn save(comptime data: anytype, comptime file_name: []const u8) !void {
    const T, const ptr = switch (@typeInfo(@TypeOf(data))) {
        .pointer => |p| if (@typeInfo(p.child) == .@"struct")
                .{p.child, @as(?*p.child,@ptrCast(data))}
            else
                @compileError("Pointer has to point to a struct"),
        .type => .{data, null},
        else => @compileError("Only types and pointer to structs allowed"),
    };

    const saveable_data =
        if (ptr == null) getTypeSaveable(T)
        else getStructSaveable(T, ptr.?);

    var dir = try std.fs.cwd().makeOpenPath("saves", .{});
    defer dir.close();
    var file = try dir.createFile(file_name ++ ".zon", .{ .truncate = true });
    defer file.close();

    var writer = file.writer(&.{});
    try std.zon.stringify.serialize(
        saveable_data,
        .{.whitespace = true},
        &writer.interface
    );
}

pub fn load(allocator: std.mem.Allocator, comptime data: anytype, comptime file_name: []const u8) !void {
    const T, const ptr = switch (@typeInfo(@TypeOf(data))) {
        .pointer => |p| if (@typeInfo(p.child) == .@"struct")
                .{p.child, @as(?*p.child,@ptrCast(data))}
            else
                @compileError("Pointer has to point to a struct"),
        .type => .{data, null},
        else => @compileError("Only types and pointer to structs allowed"),
    };

    const saveable_data,
    const saveable_field_count =
        comptime blk: { 
            const saveable = if (ptr == null) getTypeSaveable(T)
                else getStructSaveable(T, ptr.?);
            const field_count = @typeInfo(@TypeOf(saveable)).@"struct".fields.len;
            break :blk .{saveable, field_count};
        };

    var dir = try std.fs.cwd().makeOpenPath("saves", .{});
    defer dir.close();
    var file = dir.openFile(
        file_name ++ ".zon",
        .{ .mode = .read_only }
    ) catch return;
    defer file.close();

    var buf = [_:0]u8{0} ** 4096;
    var reader = file.reader(&.{});
    const char_count = try reader.interface.readSliceShort(&buf);

    const parsed = try std.zon.parse.fromSlice(
        @TypeOf(saveable_data),
        allocator,
        buf[0..char_count:0],
        null,
        .{},
    );

    inline for (0..saveable_field_count) |i| {
        saveable_data[i].* = parsed[i].*;
    }
}

fn getTypeSaveable(comptime T: type)
    @typeInfo(@TypeOf(@field(T, "getSaveable"))).@"fn".return_type.?
{
    const f = @field(T, "getSaveable");
    return f();
}

fn getStructSaveable(comptime T: type, comptime data: *T)
    @typeInfo(@TypeOf(@field(T, "getSaveable"))).@"fn".return_type.?
{
    const f = @field(T, "getSaveable");
    return f(data);
}
