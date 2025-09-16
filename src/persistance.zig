const std =  @import("std");

// TODO Make a generic gunction that fetches all saveables from a list of names

/// data is expected to have a `getSaveable()` function.
pub fn save(comptime file_name: []const u8, comptime data: anytype) !void {
    const T = switch (@typeInfo(@TypeOf(data))) {
        .pointer => |p| if (@typeInfo(p.child) == .@"struct") p.child
            else @compileError("Pointer has to point to a struct"),
        .type => data,
        else => @compileError("Only types and pointer to structs allowed"),
    };

    // TODO BROKEN AF
    const saveable = switch (@typeInfo(T)) {
        .type => blk: {
            if (!@hasDecl(data, "Saveable"))
                @compileError("Struct `Saveable` required for saving data");
            const Saveable = @field(data, "Saveable");

            if (!@hasDecl(data, "getSaveable"))
                @compileError("function `getSaveable` required for saving data");
            const f = @field(data, "getSaveable");

            break :blk getTypeSaveable(Saveable, f);
        },
        .@"struct" => blk: {
            if (!@hasDecl(T, "Saveable"))
                @compileError("Struct `Saveable` required for saving data");
            const Saveable = @field(T, "Saveable");

            if (!@hasDecl(T, "getSaveable"))
                @compileError("function `getSaveable` required for saving data");
            const f = @field(T, "getSaveable");

            break :blk getStructSaveable(Saveable, f, data);
        },
        else => unreachable,
    };

    var dir = try std.fs.cwd().makeOpenPath("saves", .{});
    defer dir.close();
    var file = try dir.createFile(file_name, .{ .truncate = true });
    defer file.close();
    var writer = file.writer(&.{});
    try std.zon.stringify.serialize(
        saveable,
        .{.whitespace = true},
        &writer.interface
    );
}

fn getTypeSaveable(T: type, func: anytype) T {
    return func();
}

fn getStructSaveable(T: type, func: anytype, ctx: anytype) T {
    return func(ctx);
}

// pub fn load()
