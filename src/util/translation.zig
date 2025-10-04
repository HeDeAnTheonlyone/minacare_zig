//! Holds all the texts of the game in the current selected language.

const std = @import("std");
const settings = @import("../lib.zig").app.settings;
const Allocator = std.mem.Allocator;

const csvSeparator = '|';
var arena: std.heap.ArenaAllocator = undefined;
pub var languages: [][]const u8 = undefined;
var dictionary: std.StringHashMapUnmanaged([:0]const u8) = undefined;

pub fn init(allocator: Allocator, selected_language: u8) !void {
    arena = std.heap.ArenaAllocator.init(allocator);
    try loadTranslationData(allocator, selected_language);
}

pub fn deinit(allocator: Allocator) void {
    arena.deinit();
    for (0..languages.len) |i| {
        allocator.free(languages[i]);
    }
    allocator.free(languages);
}

fn loadTranslationData(scratch_allocator: Allocator, selected_language: u8) !void {
    var dir = try std.fs.cwd().openDir("assets/translation", .{});
    defer dir.close();
    var file = try dir.openFile("translation.csv", .{ .mode = .read_only });
    defer file.close();

    try generateAvailableLanguagesList(scratch_allocator, file);
    try file.seekTo(0);
    try generateTranslationMap(arena.allocator(), file, selected_language);
}

fn generateAvailableLanguagesList(allocator: Allocator, file: std.fs.File) !void {
    var r_buf: [4096]u8 = undefined;
    var w_buf: [4096]u8 = undefined;
    var reader = file.reader(&r_buf);
    var writer = std.io.Writer.fixed(&w_buf);
    
    _ = try reader.interface.streamDelimiter(&writer, '\n');
    const lang_count = std.mem.count(u8, writer.buffered(), &.{csvSeparator});
    languages = try allocator.alloc([]const u8, lang_count);

    var iter = std.mem.splitScalar(u8, writer.buffered(), csvSeparator);
    _ = iter.first();

    var index: u8 = 0;
    while(iter.next()) |lang| : (index += 1) {
        languages[index] = try allocator.dupe(u8, lang);
    }
}

fn generateTranslationMap(allocator: Allocator, file: std.fs.File, selected_language: u8) !void {
    dictionary = .empty;
    try dictionary.ensureTotalCapacity(allocator, 1024);

    var r_buf: [1024 * 64]u8 = undefined;
    var w_buf: [4096]u8 = undefined;
    var reader = file.reader(&r_buf);
    var writer = std.io.Writer.fixed(&w_buf);

    var first_loop = true;
    while (true) {
        const count = reader.interface.streamDelimiter(&writer, '\n') catch |err|
            switch (err) {
                error.EndOfStream => writer.end,
                else => return err,
            };

        if (
            count > 1 and
            !std.mem.startsWith(
                u8,
                std.mem.trimStart(u8, writer.buffered(), " "),
                "#"
            )
        ) {
            if (first_loop) first_loop = false
            else {
                try registerTranslation(
                    allocator,
                    writer.buffered(),
                    selected_language
                );
            }

            if (reader.atEnd()) break;
        }
        reader.interface.toss(1);
        writer.end = 0;
    }
}

fn registerTranslation(allocator: Allocator, csvLine: []const u8, language_index: u8) !void {
    var iter = std.mem.splitScalar(u8, csvLine, csvSeparator);

    const key = iter.first();
    if (language_index > 0)
        for (0..language_index) |_| { _ = iter.next() orelse return; };
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

pub fn reloadTranslationData(selected_language: u8) !void {
    _ = arena.reset(.retain_capacity);

    var dir = try std.fs.cwd().openDir("assets/translation", .{});
    defer dir.close();
    var file = try dir.openFile("translation.csv", .{ .mode = .read_only });
    defer file.close();

    try generateTranslationMap(arena.allocator(), file, selected_language);
}

pub const Translatable = struct {
    id: []const u8,
    text: ?[:0]const u8 = null,
    language: u8,

    pub fn init(comptime id: []const u8) Translatable {
        return .{
            .id = id,
            .language = 0,
        };
    }

    /// Caches and returns the translated string.
    pub fn translate(self: *Translatable) [:0]const u8 {
        if (
            self.text == null or
            self.language != settings.selected_language
        ) {
            self.text = dictionary.get(self.id) orelse "ERROR";
            self.language = settings.selected_language;
        }
        return self.text.?;
    }
};