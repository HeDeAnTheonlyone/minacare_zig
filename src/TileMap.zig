const std = @import("std");
const settings = @import("settings.zig");
const drawer = @import("drawer.zig");
const rl = @import("raylib").raylib_module;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

/// Texture should be the same regardless what world map is loaded as all tiles should ideally be in the same file.
texture: rl.Texture2D,
map_data: RuntimeMap,
/// 2 layers * 9 chunks * 32 tiles horizontal * 32 tiles vertical
tile_render_cache: [2 * 9 * 32 * 32]TileDrawData = undefined,
current_chunk: ChunkCoordinates,
counter: u32 = 0,
sub_frame_counter: f32 = 0,

const Self = @This();
const tile_spritesheet_path = "assets/textures/tile_spritesheet.png";
const frame_time: u8 = 5;

/// Deinitialize with `deinit()`.
pub fn init(allocator: std.mem.Allocator, map_name: []const u8, initial_render_position: Vector2) !Self {
    var  map = Self{
        .texture = try rl.loadTexture(tile_spritesheet_path),
        .map_data = try RuntimeMap.loadFromFile(allocator, map_name),
        // 1 is added to make it different from the players chunk coordinates and trigger the cache update function
        .current_chunk = getChunkCoordFromPos(initial_render_position).addValue(1),
    };
    try Self.updateTileRenderCache(&map, initial_render_position);
    return map;
}

pub fn updateCallback(self_: *anyopaque, delta: f32) !void {
    const self: Self = @alignCast(@ptrCast(self_));
    self.update(delta);
}

pub fn update(self: *Self, delta: f32) void {
    self.updateCounter(delta);
}

fn updateCounter(self: *Self, delta: f32) void {
    const base_framerate = 60;
    self.sub_frame_counter += base_framerate * delta;
    if (self.sub_frame_counter < frame_time) return;
    self.sub_frame_counter = 0;
    self.counter += 1;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.texture.unload();
    self.map_data.deinit(allocator);
}

pub fn draw(self: *Self) void {
    for (self.tile_render_cache) |draw_data| {
        var tmp_source_rect = draw_data.source_rect;
        if (draw_data.properties != null and draw_data.properties.?.frames != null) {
            tmp_source_rect.shift(
                .x,
                @floatFromInt(settings.tile_size * @rem(self.counter, draw_data.properties.?.frames.?))
            );
        }

        drawer.drawTexturePro(
            self.texture,
            tmp_source_rect,
            draw_data.dest_rect,
            Vector2.zero(),
            0,
            rl.Color.white
        );
    }

    if (@import("builtin").mode == .Debug) {
        self.debugDraw();
    }
}

fn debugDraw(self: *Self) void {
    const debug = @import("debug.zig");
    if(debug.show_tile_map_collisions) {
        var iter = self.map_data.collision_map.collision_shapes.iterator();
        while (iter.next()) |collision_shape| {
            drawer.drawRectOutline(
                collision_shape.value_ptr.*,
                5,
                rl.Color.blue
            );
        }
    }
}

pub fn updateTileRenderCacheCallback(self_: *anyopaque, player_pos: Vector2) !void {
    const self: *Self = @alignCast(@ptrCast(self_));
    try self.updateTileRenderCache(player_pos);
}

pub fn updateTileRenderCache(self: *Self, player_pos: Vector2) !void {
    if (self.current_chunk.equals(getChunkCoordFromPos(player_pos))) return;
    self.current_chunk = getChunkCoordFromPos(player_pos);

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

    var index: usize = 0;

    for (self.map_data.tile_map.layers) |layer| {
        for (chunk_offsets) |offset| {
            const current_chunk_coords = player_chunk.add(offset);
            const chunk = layer.chunks.get(current_chunk_coords)
                orelse if (@import("builtin").mode == .Debug) RuntimeMap.TileMap.TileLayer.TileChunk.getErrorChunk(current_chunk_coords)
                    else continue;

            for (0..chunk.tile_ids.len) |i| {
                const tile_source_rect =
                    if (chunk.tile_ids[i] == -1) continue
                    else Rectangle.init(
                        @floatFromInt(@mod(chunk.tile_ids[i] * settings.tile_size, self.texture.width)),
                        @floatFromInt(@divFloor(chunk.tile_ids[i] * settings.tile_size, self.texture.width) * settings.tile_size),
                        settings.tile_size,
                        settings.tile_size
                    );

                // Column and row from the chunk
                const chunk_column: i32 = @intCast(@mod(i, settings.chunk_size));
                const chunk_row: i32 = @intCast(@divFloor(i, settings.chunk_size));

                const tile_dest_rect = Rectangle.init(
                    @as(f32, @floatFromInt(chunk.x * settings.tile_size + chunk_column * settings.tile_size)),
                    @as(f32, @floatFromInt(chunk.y * settings.tile_size + chunk_row * settings.tile_size)),
                    settings.tile_size,
                    settings.tile_size,
                );

                self.tile_render_cache[index] = .{
                    .source_rect = tile_source_rect,
                    .dest_rect = tile_dest_rect,
                    .properties = self.map_data.tile_map.tile_properties.getPtr(chunk.tile_ids[i]),
                };
                index += 1;
            }
        }
    }
}

const TileDrawData = struct {
    source_rect: Rectangle,
    dest_rect: Rectangle,
    properties: ?*RuntimeMap.TileMap.TileProperties,
};

/// Chunk coordinates are the position divided by the tile size and the chunk size.
pub fn getChunkCoordFromPos(native_pos: Vector2) ChunkCoordinates {
    return Coordinates
        .fromPosition(native_pos)
        .divideScalar(settings.chunk_size);
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
            const x = @as(i32, @intFromFloat(pos.x));
            const y = @as(i32, @intFromFloat(pos.y));
            return Coordinates.divideScalar(
                .{ .x = x, .y = y },
                settings.tile_size,
            );
        }

        pub fn splat(scalar: i32) SelfCoords {
            return .{
                .x = scalar,
                .y = scalar,
            };
        }

        pub fn equals(self: SelfCoords, other: SelfCoords) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn add(self: SelfCoords, addend: SelfCoords) SelfCoords {
            return .{
                .x = self.x + addend.x,
                .y = self.y + addend.y,
            };
        }

        pub fn addValue(self: SelfCoords, addend: i32) SelfCoords {
            return .{
                .x = self.x + addend,
                .y = self.y + addend,
            };
        }

        pub fn subtract(self: SelfCoords, subtrahend: SelfCoords) SelfCoords {
            return .{
                .x = self.x - subtrahend.x,
                .y = self.y - subtrahend.y,
            };
        }

        pub fn subtractValue(self: SelfCoords, subtrahend: i32) SelfCoords {
            return .{
                .x = self.x - subtrahend,
                .y = self.y - subtrahend,
            };
        }

        pub fn multiplyScalar(self: SelfCoords, multiplicant: i32) SelfCoords {
            return .{
                .x = self.x * multiplicant,
                .y = self.y * multiplicant,
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

        pub fn modScalar(self: *SelfCoords, divisor: i32) SelfCoords {
            return .{
                .x = @rem(self.x, divisor),
                .y = @rem(self.y, divisor),
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
            tile_properties: switch (value_container) {
                .Array => []TileProperties,
                .HashMap =>std.AutoHashMapUnmanaged(i32, TileProperties),
            },

            pub const TileProperties = struct {
                id: i32,
                frames: ?u8 = null,
            };

            pub const TileLayer = struct {
                chunks: switch (value_container) {
                    .Array => []TileChunk,
                    .HashMap => std.AutoHashMapUnmanaged(Coordinates, TileChunk),
                },
                x: i32,
                y: i32,
                width: u32, // In tiles
                height: u32, // In tiles
                name: []const u8,

                pub const TileChunk = struct {
                    tile_ids: []const i32,
                    x: i32, // Coordinate not position
                    y: i32, // Coordinate not position
                    
                    /// Chunk coordinates are the position divided by the tile size and the chunk size.
                    pub fn getChunkCoord(self: TileChunk) ChunkCoordinates {
                        return Coordinates.divideScalar(
                            .{.x = self.x, .y = self.y},
                            settings.chunk_size);
                    }

                    /// Returns an error chunk for the given chunk coordinates.
                    /// It has every tile filled with an error texture.
                    pub fn getErrorChunk(coords: ChunkCoordinates) TileChunk {
                        return .{
                            .x = coords.x * settings.chunk_size,
                            .y = coords.y * settings.chunk_size,
                            .tile_ids = &[_]i32{63} ** 1024,
                        };
                    }   
                };
            };
        };

        pub const CollisionMap = struct {
            collision_shapes: switch (value_container) {
                .Array => []Rectangle,
                .HashMap => std.AutoHashMapUnmanaged(Coordinates, Rectangle),
            },

            pub fn getTileCollision(self: *CollisionMap, player_pos: Vector2) ?Rectangle {
                const coords = Coordinates.fromPosition(player_pos);
                return self.collision_shapes.get(coords);
            }
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

            // Map stored map data to RuntimeMap struct
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
                            try chunk_map.ensureTotalCapacity(allocator, 128);
                            // TODO maybe increase as time goes on. -------------------------/\
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
                    },
                    .tile_properties = blk: {
                        var tile_property_list = std.AutoHashMapUnmanaged(
                            i32,
                            TileMap.TileProperties
                        ).empty;
                        try tile_property_list.ensureTotalCapacity(allocator, 128);
                        // TODO maybe increase as time goes on. ---------------/\
                        for (stored_map.tile_map.tile_properties) |prop| {
                            try tile_property_list.put(
                                allocator,
                                prop.id,
                                prop,
                            );
                        }
                        break :blk tile_property_list;
                    },
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
                    },
                },
                .markers = stored_map.markers,
            };
            return runtime_map;
        }
    };
}
