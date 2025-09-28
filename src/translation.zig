//! Holds all the texts of the game in the current selected language.

const std = @import("std");
const settings = @import("settings.zig");
const Allocator = std.mem.Allocator;

const csvSeparator = ';';
var arena: std.heap.ArenaAllocator = undefined;
pub var dictionary: std.StringHashMapUnmanaged([:0]const u8) = undefined;

pub fn init(allocator: Allocator) !void {
    arena = std.heap.ArenaAllocator.init(allocator);
    try generateTranslationMap(arena.allocator());
}

pub fn deinit() void {
    arena.deinit();
}

fn generateTranslationMap(allocator: Allocator) !void {
    dictionary = .empty;
    try dictionary.ensureTotalCapacity(allocator, 1024);

    var dir = try std.fs.cwd().openDir("assets/translation", .{});
    defer dir.close();
    var file = try dir.openFile("translation.csv", .{ .mode = .read_only });
    defer file.close();

    var r_buf: [1024 * 64]u8 = undefined;
    var w_buf: [4096]u8 = undefined;
    var reader = file.reader(&r_buf);
    var writer = std.io.Writer.fixed(&w_buf);

    var language_index: u8 = 0;
    while (true) {
        _ = reader.interface.streamDelimiter(&writer, '\n') catch |err| {
            switch (err) {
                error.EndOfStream => {},
                else => return err,
            }
        };

        if (language_index == 0) { // index 0 is for translation keys
            var iter = std.mem.splitScalar(u8, writer.buffered(), csvSeparator);
            var index: u8 = 0;
            while (iter.next()) |lang| : (index += 1) {
                if (std.mem.eql(u8, lang, @tagName(settings.language))) break;
            }
            language_index = index;
        }
        else {
            try registerTranslation(
                allocator,
                writer.buffered(),
                language_index
            );
        }
        
        if (reader.atEnd()) break;
        reader.interface.toss(1);
        writer.end = 0;
    }
}

fn registerTranslation(allocator: Allocator, csvLine: []const u8, language_index: u8) !void {
    std.debug.assert(csvLine.len != 0);
    var iter = std.mem.splitScalar(u8, csvLine, csvSeparator);
    
    const key = iter.first();
    if (language_index - 1 > 0)
        for (0..language_index - 1) |_| { _ = iter.next().?; };
    const value = blk: {
        const v = iter.next() orelse "ERROR";
        if (v.len == 0) break :blk "ERROR"
        else break :blk v;
    };

    try dictionary.put(
        allocator,
        try allocator.dupe(u8, key),
        try allocator.dupeZ(u8, value),
    );
}

pub const Translatable = struct {
    id: []const u8,
    text: ?[:0]const u8 = null,

    /// Caches and returns the translation.
    pub fn translate(self: *const Translatable) [:0]const u8 {
        if (self.text == null) @constCast(self).text = dictionary.get(self.id).?;
        return self.text.?;
    }
};