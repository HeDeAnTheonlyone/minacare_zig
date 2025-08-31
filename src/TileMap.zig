const std = @import("std");
const rl = @import("raylib").raylib_module;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;
const settings = @import("Settings.zig");

/// Texture should be the same regardless what world map is loaded as all tiles should ideally be in the same file.
texture: rl.Texture2D,
map_data: RuntimeMap,

const Self = @This();
const tile_spritesheet_path = "assets/textures/tile_spritesheet.png";

/// Deinitialize with `deinit()`.
pub fn init(allocator: std.mem.Allocator, map_name: []const u8) !Self {
    return .{
        .texture = try rl.loadTexture(tile_spritesheet_path),
        .map_data = try RuntimeMap.loadFromFile(allocator, map_name),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    rl.unloadTexture(self.texture);
    self.map_data.deinit(allocator);
}

pub fn draw(self: *Self, player_pos: Vector2) !void {
    const player_chunk = getChunkCoordFromPos(player_pos);
    const chunk_offsets: [9]ChunkCoordinates = .{
        .{.x = -1, .y = -1},
        .{.x = 0, .y = -1},
        .{.x = 1, .y = -1},
        .{.x = -1, .y = 0},
        .{.x = 0, .y = 0},
        .{.x = 1, .y = 0},
        .{.x = -1, .y = 1},
        .{.x = 0, .y = 1},
        .{.x = 1, .y = 1},
    };
    
    for (self.map_data.tile_map.layers) |layer| {
        for (chunk_offsets) |offset| {
            const current_chunk_coords = player_chunk.add(offset);
            const chunk = layer.chunks.get(current_chunk_coords) orelse continue;
            
            for (0..chunk.tile_ids.len) |i| {
                const column = @mod(i, settings.chunk_size);
                const row = @mod(@divFloor(i, settings.chunk_size), settings.chunk_size);
                const tile_pos_x = chunk.x + @as(i32, @intCast(column)) * settings.tile_size;
                const tile_pos_y = chunk.y + @as(i32, @intCast(row)) * settings.tile_size;

                const id = @as(i32, @intCast(chunk.tile_ids[i])) - 1;

                const tile_rect =
                    if (id == -1) continue
                    else Rectangle.init(
                        @floatFromInt(@mod(@as(i32, @intCast(id)) * settings.tile_size, @as(i32, self.texture.width))),
                        @floatFromInt(@mod(@divFloor(@as(i32, @intCast(id)) * settings.tile_size, self.texture.width), self.texture.height)),
                        settings.tile_size,
                        settings.tile_size
                    );

                rl.drawTexturePro(
                    self.texture,
                    tile_rect,
                    Rectangle.init(
                        @as(f32, @floatFromInt(tile_pos_x)) * settings.getRsolutionRatio(),
                        @as(f32, @floatFromInt(tile_pos_y)) * settings.getRsolutionRatio(),
                        settings.tile_size * settings.getRsolutionRatio(),
                        settings.tile_size * settings.getRsolutionRatio(),
                    ),
                    Vector2.zero(),
                    0,
                    rl.Color.white
                );
            }
        }
    }
}

/// Chunk coordinates are the position divided by the tile size and the chunk size.
pub fn getChunkCoordFromPos(pos: Vector2) ChunkCoordinates {
    const coord_pos = Coordinates.fromPosition(pos);
    return coord_pos.divideScalar(settings.chunk_size);
}

pub const Coordinates = CoordinatesDef();
pub const ChunkCoordinates = CoordinatesDef();

pub fn CoordinatesDef() type {
    return struct {
        x: i32,
        y: i32,

        const SelfCoords = @This();

        /// Coordinate are position divided by the tile size.
        pub fn fromPosition(pos: Vector2) Coordinates {
            return Coordinates.divideScalar(
                .{
                    .x = @intFromFloat(pos.x),
                    .y = @intFromFloat(pos.y),
                },
                settings.tile_size,
            );
        }

        pub fn add(self: SelfCoords, addend: SelfCoords) SelfCoords {
            return .{
                .x = self.x + addend.x,
                .y = self.y + addend.y,
            };
        }

        pub fn divide(self: SelfCoords, divisor: SelfCoords) SelfCoords {
            return .{
                .x = @divFloor(self.x, divisor.x),
                .y = @divFloor(self.y, divisor.y),
            };
        }

        pub fn divideScalar(self: SelfCoords, divisor: i32) SelfCoords {
            return .{
                .x = @divFloor(self.x, divisor),
                .y = @divFloor(self.y, divisor),
            };
        }
    };
}

pub const ContainerType = enum {
    Array,
    HashMap,
};

pub const StoredMap = MapDataDef(.Array);
pub const RuntimeMap = MapDataDef(.HashMap);

pub fn MapDataDef(comptime value_container: ContainerType) type {
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
                    
                    /// Chunk coordinates are the position divided by the tile size and the chunk size.
                    pub fn getChunkCoord(self: TileChunk) ChunkCoordinates {
                        const coord_pos = ChunkCoordinates.divideScalar(
                            .{.x = self.x, .y = self.y},
                            settings.tile_size
                        );
                        return coord_pos.divideScalar(settings.chunk_size);
                    }
                };
            };
        };

        pub const CollisionMap = struct {
            collision_shapes: switch (value_container) {
                .Array => []Rectangle,
                .HashMap => std.AutoHashMapUnmanaged(Coordinates, Rectangle),
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

        /// Load only the internal map data and not the texture.
        /// File name refers to only the file name without the extension and not the whole path.
        /// Deinitialize with `deinit()`.
        pub fn loadFromFile(allocator: std.mem.Allocator, file_name: []const u8) !RuntimeMap {
            const path = try std.mem.concat(allocator, u8, &.{"assets/maps/", file_name, ".zon"});
            defer allocator.free(path);
            var map_file = try std.fs.cwd().openFile(path, .{});
            defer map_file.close();
            return load(allocator, &map_file);
        }

        /// Deinitialize with `deinit()`.
        fn load(allocator: std.mem.Allocator, file: *std.fs.File) !RuntimeMap {
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
                        var tile_layers = try allocator.alloc(
                            RuntimeMap.TileMap.TileLayer,
                            stored_map.tile_map.layers.len
                        );
                        for (0..tile_layers.len) |i|{
                            var chunk_map = std.AutoHashMapUnmanaged(
                                Coordinates,
                                RuntimeMap.TileMap.TileLayer.TileChunk
                            ).empty;
                            for (stored_map.tile_map.layers[i].chunks) |chunk| {
                                try chunk_map.put(
                                    allocator,
                                    chunk.getChunkCoord(),
                                    .{
                                        .tile_ids = chunk.tile_ids,
                                        .x = chunk.x,
                                        .y = chunk.y,
                                    },
                                );
                            }
                            tile_layers[i].chunks = chunk_map;
                        }
                        break :blk tile_layers;
                    }
                },
                .collision_map = RuntimeMap.CollisionMap{
                    .collision_shapes = blk: {
                        var collisions = std.AutoHashMapUnmanaged(
                            Coordinates,
                            Rectangle
                        ).empty;
                        for (stored_map.collision_map.collision_shapes) |rect| {
                            try collisions.put(
                                allocator,
                                Coordinates.fromPosition(.{
                                    .x = rect.x,
                                    .y = rect.y,
                                }),
                                @bitCast(rect));
                        }
                        break :blk collisions;
                    }
                },
                .markers = stored_map.markers,
            };
            return runtime_map;
        }
    };
}