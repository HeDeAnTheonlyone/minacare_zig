const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const StoredMap = @import("StoredMap.zig");
const TileMap = StoredMap.TileMap;
const Marker = StoredMap.Marker;
const Rectangle = rl.Rectangle;

pub const Coordinates = struct {
    x: i32,
    y: i32,
};

pub const Map = struct {
    tile_map: TileMap,
    collision_map: CollisionMap,
    markers: []const Marker,

    const Self = @This();

    // Redefined for runtime use because it's more performant
    pub const CollisionMap = struct {
        collision_shapes: std.AutoHashMapUnmanaged(Coordinates,Rectangle),
    };

    pub fn draw(self: *Self) void {
        for (self.tile_map.layers) |layer| {
            for (layer.chunks) |chunk| {
                //TODO WIP
            }
        }
    }

    /// Use deinit() to free memory.
    pub fn load(allocator: std.mem.Allocator, file: *std.fs.File) !Map {
        var file_content = std.Io.Writer.Allocating.init(allocator);
        defer file_content.deinit();
        var file_reader = file.reader(&.{});
        const content_len = try std.Io.Reader.streamRemaining(&file_reader.interface, &file_content.writer);

        const sentinel_zon_str: [:0]u8 = try allocator.allocSentinel(u8, content_len, 0);
        defer allocator.free(sentinel_zon_str);
        @memcpy(sentinel_zon_str, file_content.written());

        const stored_map = try std.zon.parse.fromSlice(
            StoredMap,
            allocator,
            sentinel_zon_str,
            null,
            .{}
        );

        const map = Map{
            .tile_map = stored_map.tile_map,
            .markers = stored_map.markers,
            .collision_map = Map.CollisionMap{
                .collision_shapes = blk: {
                    var collisions = std.AutoHashMapUnmanaged(Coordinates, Rectangle).empty;
                    for (stored_map.collision_map.collision_shapes) |entry| {
                        const coodinates_vec = rl.Vector2.divide(@bitCast(entry.key), .{.x = settings.tile_size, .y = settings.tile_size}); 
                        try collisions.put(
                            allocator,
                            Coordinates{.x = @intFromFloat(coodinates_vec.x), .y = @intFromFloat(coodinates_vec.y)},
                            @bitCast(entry.value));
                    }
                    break :blk collisions;
                }
            }
        };
        return map;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.collision_map.collision_shapes.deinit(allocator);
    }
};
