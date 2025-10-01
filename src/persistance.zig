const std =  @import("std");
const app_context = @import("app_context.zig");

/// Names for all save files.
const save_files = enum {
    debug,
    settings,
    player,
};

const deletable_files = enum {
    player,
};

/// File name is without the extension.
/// Data is expected to have a `getSaveable()` function.
pub fn save(comptime data: anytype, comptime save_file: save_files) void {
    const T, const ptr = switch (@typeInfo(@TypeOf(data))) {
        .pointer => |p| if (@typeInfo(p.child) == .@"struct")
                .{p.child, @as(?*p.child,@ptrCast(data))}
            else
                @compileError("Pointer has to point to a struct"),
        .type => .{data, null},
        else => @compileError("Only types and pointer to structs allowed"),
    };

    const file_name = @tagName(save_file);
    const saveable_data =
        if (ptr == null) getTypeSaveable(T)
        else getStructSaveable(T, ptr.?);

    var dir = std.fs.cwd().makeOpenPath("saves", .{}) catch {
        reportErr(.access, file_name);
        return;
    };
    defer dir.close();
    var file = dir.createFile(file_name ++ ".zon", .{ .truncate = true }) catch {
        reportErr(.access, file_name);
        return;
    };
    defer file.close();

    var writer = file.writer(&.{});
    std.zon.stringify.serialize(
        saveable_data,
        .{.whitespace = true},
        &writer.interface
    ) catch {
        reportErr(.save, file_name);
        return;
    };
}

/// File name is without the extension.
/// Data is expected to have a `getSaveable()` function.
pub fn load(comptime data: anytype, comptime save_file: save_files) void {
    const T, const ptr = switch (@typeInfo(@TypeOf(data))) {
        .pointer => |p| if (@typeInfo(p.child) == .@"struct")
                .{p.child, @as(?*p.child, @ptrCast(data))}
            else
                @compileError("Pointer has to point to a struct"),
        .type => .{data, null},
        else => @compileError("Only types and pointer to structs allowed"),
    };

    const file_name = @tagName(save_file);
    const saveable_data,
    const saveable_field_count =
        comptime blk: { 
            const saveable =
                if (ptr == null) getTypeSaveable(T)
                else getStructSaveable(T, ptr.?);
            const field_count = @typeInfo(@TypeOf(saveable)).@"struct".fields.len;
            break :blk .{saveable, field_count};
        };

    var dir = std.fs.cwd().makeOpenPath("saves", .{}) catch {
        reportErr(.access, file_name);
        return;
    };
    defer dir.close();
    var file = dir.openFile(
        file_name ++ ".zon",
        .{ .mode = .read_only }
    ) catch return;
    defer file.close();

    var buf: [4096:0]u8 = @splat(0);
    var reader = file.reader(&.{});
    const char_count = reader.interface.readSliceShort(&buf) catch {
        reportErr(.access, file_name);
        return;
    };

    const parsed = std.zon.parse.fromSlice(
        @TypeOf(saveable_data),
        app_context.gpa,
        buf[0..char_count:0],
        null,
        .{},
    ) catch {
        reportErr(.access, file_name);
        return;
    };

    inline for (0..saveable_field_count) |i| {
        saveable_data[i].* = parsed[i].*;
    }
}

/// Deletes all the game's progress but not the settings.
pub fn delete() !void {
    var dir = try std.fs.cwd().openDir("saves", .{.iterate = true});
    defer dir.close();

    var iter  = dir.iterate();

    // TODO maybe just change the name of the files to backup_<file name>.zon

    outer: while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file =>  {
                _ = std.meta.stringToEnum(
                    deletable_files,
                    entry.name[0..entry.name.len - 4],
                ) orelse continue :outer;
                
                try dir.deleteFile(entry.name);
            },
            else => {},
        }
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

fn reportErr(action: enum{access, load, save} ,comptime file_name: []const u8) void {
    var err_writer = std.fs.File.stderr().writer(&.{});

    // TODO maybe think of a different way to show the error.

    switch (action) {
        .access => err_writer.interface.writeAll("Save file " ++ file_name ++ "could not be accessed") catch {},
        .load => err_writer.interface.writeAll("Save file creation/update for " ++ file_name ++ " failed") catch {},
        .save => err_writer.interface.writeAll("Save file loading for " ++ file_name ++ " failed") catch {},
    }
}
