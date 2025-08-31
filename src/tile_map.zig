const std = @import("std");
const rl = @import("raylib").raylib_module;
const settings = @import("Settings.zig");

pub const ContainerType = enum {
    Array,
    HashMap,
};

pub const Coordinates = struct {
    x: i32,
    y: i32,
};

pub const StoredMap = Map(.Array);
pub const RuntimeMap = Map(.HashMap);

pub fn Map(comptime value_container: ContainerType) type {
    return struct {
        tile_map: TileMap,
        collision_map: CollisionMap,
        markers: []Marker,

        pub const TileMap = struct {
            layers: []TileLayer,

            pub const TileLayer = struct {
                chunks: switch (value_container) {
                    .Array => []TileChunk,
                    .HashMap => std.AutoHashMapUnmanaged(Coordinates, TileChunk)
                },
                x: i32,
                y: i32,
                width: u32, // In tiles
                height: u32, // In tiles
                name: []const u8,

                pub const TileChunk = struct {
                    tile_ids: []const u32,
                    x: i32,
                    y: i32,
                };
            };
        };

        pub const CollisionMap = struct {
            collision_shapes: switch (value_container) {
                .Array => []rl.Rectangle,
                .HashMap => std.AutoHashMapUnmanaged(Coordinates, rl.Rectangle),
            },
        };

        pub const Marker = struct {
            x: i32,
            y: i32,
            kind: Kind,
            name: []const u8,

            pub const Kind = enum(u8) {
                Checkpoint,
                Spawn,
            };
        };

        pub fn deinit(self: *RuntimeMap, allocator: std.mem.Allocator) void {
            self.collision_map.collision_shapes.deinit(allocator);
        }
    };
}

pub fn load(allocator: std.mem.Allocator, file: *std.fs.File) !RuntimeMap {
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

    const runtime_map = RuntimeMap{
        .tile_map = .{
            .layers = blk: {
                var tile_layers = try allocator.alloc(RuntimeMap.TileMap.TileLayer, stored_map.tile_map.layers.len);
                for (0..tile_layers.len) |i|{
                    var chunk_map = std.AutoHashMapUnmanaged(Coordinates, RuntimeMap.TileMap.TileLayer.TileChunk).empty;
                    for (stored_map.tile_map.layers[i].chunks) |chunk| {
                        const c = @as(RuntimeMap.TileMap.TileLayer.TileChunk, chunk);
                        try chunk_map.put(
                            allocator,
                            Coordinates{
                                .x = @divTrunc(c.x, settings.tile_size),
                                .y = @divTrunc(c.y, settings.tile_size)
                            },
                            c,
                        );
                    }
                    tile_layers[i].chunks = chunk_map;
                }
                break :blk tile_layers;
            }
        },
        .markers = stored_map.markers,
        .collision_map = RuntimeMap.CollisionMap{
            .collision_shapes = blk: {
                var collisions = std.AutoHashMapUnmanaged(Coordinates, rl.Rectangle).empty;
                for (stored_map.collision_map.collision_shapes) |rect| {
                    const r = @as(rl.Rectangle, rect);
                    try collisions.put(
                        allocator,
                        Coordinates{
                            .x = @intFromFloat(r.x / settings.tile_size),
                            .y = @intFromFloat(r.y / settings.tile_size)
                        },
                        @bitCast(r));
                }
                break :blk collisions;
            }
        }
    };
    return runtime_map;
}