const std = @import("std");
const rl = @import("raylib").raylib_module;
const lib = @import("../lib.zig");
const app = lib.app;
const game = lib.game;
const util = lib.util;
const settings = app.settings;
const game_state = game.state;
const drawer = util.drawer;
const Vector2 = rl.Vector2;
const Rectangle = rl.Rectangle;

texture: *rl.Texture2D,
map_data: RuntimeMap = undefined,
tile_render_cache: [render_cache_size]?TileDrawData = @splat(null),
current_chunk: ChunkCoordinates = Coordinates{.x = std.math.maxInt(i32), .y = std.math.maxInt(i32)},
sub_frame_counter: f32 = 0,
arena: ?std.heap.ArenaAllocator = null,

const Self = @This();
/// 2 layers * 9 chunks * 32 tiles horizontal * 32 tiles vertical
const render_cache_size = 4 * 9 * @as(u32, @intCast(settings.chunk_size)) * @as(u32, @intCast(settings.chunk_size));

/// `backing_allocator` will be put into an arena for single call free of all the managed memory with `deinit()`.
/// 
/// Deinitialize with `deinit()`.
pub fn init(texture: *rl.Texture2D) Self {
    return .{
        .texture = texture,
    };
}

pub fn deinit(self: *Self) void {
    if (self.arena != null) self.arena.?.deinit();
}

pub fn drawCallback(self_: *anyopaque, _: void) void {
    const self: Self = @alignCast(@ptrCast(self_));
    self.draw();
} 

//TODO maybe multithread if it becomes an issue.
pub fn draw(self: *Self) !void {
    for (self.tile_render_cache) |opt_draw_data| {
        const draw_data = opt_draw_data orelse continue;
        var tmp_source_rect = draw_data.source_rect;
        if (
            draw_data.properties != null and
            draw_data.properties.?.frames != null and
            draw_data.properties.?.frame_time != null
        ) {
            const prop = draw_data.properties.?;
            const sub_frame = @as(u32, @intFromFloat(@divFloor(
                game_state.counter * settings.base_framerate,
                @as(f32, @floatFromInt(prop.frame_time.?))
            )));
            const frame = @rem(sub_frame, prop.frames.?);
            const shift = frame * settings.tile_size;

            tmp_source_rect.shift(.x, @floatFromInt(shift));
        }

        drawer.drawTexturePro(
            self.texture.*,
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
    const debug = util.debug;
    if (debug.show_tile_map_collisions) {
        var iter = self.map_data.collision_map.collision_shapes.iterator();
        while (iter.next()) |collision_shape| {
            drawer.drawRectOutline(
                collision_shape.value_ptr.*,
                5,
                rl.Color.blue
            );
        }
    }
    
    if (debug.show_current_chunk_bounds) {
        const rect = getChunkRect(self.current_chunk);
        drawer.drawRectOutline(rect, 10, .purple);
    }
}

/// Deinits old map and load new map. `map_name` refers to the file name without the extension.
pub fn loadMap(self: *Self, allocator: std.mem.Allocator, map_name: []const u8) !void {
    if (self.arena != null) self.arena.?.deinit();
    self.arena = std.heap.ArenaAllocator.init(allocator);
    self.map_data = try RuntimeMap.loadFromFile(
    self.arena.?.allocator(),
    allocator,
        map_name
    );
    try self.updateTileRenderCache(game_state.player.char.movement.pos);
}

pub fn updateTileRenderCache(self: *Self, player_pos: Vector2) !void {
    if (self.current_chunk.equals(getChunkCoordFromPos(player_pos))) return;
    self.current_chunk = getChunkCoordFromPos(player_pos);

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
            const current_chunk_coords = self.current_chunk.add(offset);
            const chunk = layer.chunks.get(current_chunk_coords)
                orelse if (@import("builtin").mode == .Debug and lib.util.debug.show_error_tiles)
                    RuntimeMap.TileMap.TileLayer.TileChunk.getErrorChunk(current_chunk_coords)
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

/// Returns a rectangle with the bounds of a chunk from the given coordinates. 
pub fn getChunkRect(coords: ChunkCoordinates) Rectangle {
    const start = coords
        .multiplyScalar(settings.chunk_size)
        .multiplyScalar(settings.tile_size)
        .toVector2();

    const size = @as(u32, @intCast(settings.chunk_size)) * @as(u32, @intCast(settings.tile_size));

    return Rectangle{
        .x = start.x,
        .y = start.y,
        .width = @floatFromInt(size),
        .height = @floatFromInt(size),
    };
}

pub const Coordinates = CoordinatesDef();
pub const ChunkCoordinates = CoordinatesDef();

pub const Location = union(enum) {
    position: Vector2,
    coordinates: Coordinates,

    /// If Vector: return value.
    /// 
    /// If Coordinates: calculate pos and then return value.
    pub fn asPos(loc: Location) Vector2 {
        return switch (loc) {
            .coordinates => |l| blk: {
                const pos = l.multiplyScalar(settings.tile_size);
                break :blk Vector2{
                    .x = @floatFromInt(pos.x),
                    .y = @floatFromInt(pos.y),
                };
            },
            .position => |l| l,
        };
    }

    pub fn asCoords(loc: Location) Coordinates {
        return switch (loc) {
            .coordinates => |l| l,
            .position => |l| Coordinates.fromPosition(l) ,
        };
    }
};

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

        pub fn modScalar(self: SelfCoords, divisor: i32) SelfCoords {
            return .{
                .x = @rem(self.x, divisor),
                .y = @rem(self.y, divisor),
            };
        }

        pub fn toVector2(self: SelfCoords) Vector2 {
            return .{
                .x = @floatFromInt(self.x),
                .y = @floatFromInt(self.y),
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
                .HashMap => std.AutoHashMapUnmanaged(i32, TileProperties),
            },

            pub const TileProperties = struct {
                id: i32,
                frames: ?u8 = null,
                frame_time: ?u8 = null,
            };

            pub const TileLayer = struct {
                chunks: switch (value_container) {
                    .Array => []TileChunk,
                    .HashMap => std.AutoHashMapUnmanaged(Coordinates, TileChunk),
                },
                // x: i32,
                // y: i32,
                // width: u32, // In tiles
                // height: u32, // In tiles
                // name: []const u8,

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
                            .tile_ids = &[_]i32{0} ** (@as(u32, @intCast(settings.chunk_size)) * @as(u32, @intCast(settings.chunk_size))),
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

        /// Load only the internal map data and not the texture.
        /// File name refers to only the file name without the extension and not the whole path.
        /// Deinitialize with `deinit()`.
        fn loadFromFile(
            arena_allocator: std.mem.Allocator,
            scratch_allocator: std.mem.Allocator,
            file_name: []const u8
        ) !RuntimeMap {
            const path = try std.mem.concat(
                scratch_allocator,
                u8,
                &.{"assets/maps/", file_name, ".zon"}
            );
            defer scratch_allocator.free(path);
            var map_file = try std.fs.cwd().openFile(path, .{});
            defer map_file.close();
            return load(
                arena_allocator,
                scratch_allocator,
                &map_file
            );
        }

        /// Deinitialize with `deinit()`.
        fn load(
            arena_allocator: std.mem.Allocator,
            scratch_allocator: std.mem.Allocator,
            file: *std.fs.File
        ) !RuntimeMap {
            var file_content = std.Io.Writer.Allocating.init(scratch_allocator);
            defer file_content.deinit();
            var file_reader = file.reader(&.{});
            const content_len = try std.Io.Reader.streamRemaining(&file_reader.interface, &file_content.writer);

            const sentinel_zon_str: [:0]u8 = try scratch_allocator.allocSentinel(u8, content_len, 0);
            defer scratch_allocator.free(sentinel_zon_str);
            @memcpy(sentinel_zon_str, file_content.written());

            const stored_map = try std.zon.parse.fromSlice(
                StoredMap,
                scratch_allocator,
                sentinel_zon_str,
                null,
                .{}
            );

            return try storedMapToRuntimeMap(arena_allocator, stored_map);
        }

        fn storedMapToRuntimeMap(arena_allocator: std.mem.Allocator, stored_map: StoredMap) !RuntimeMap {
            return RuntimeMap{
                .tile_map = .{
                    .layers = blk: {
                        var tile_layers = try arena_allocator.alloc(
                            RuntimeMap.TileMap.TileLayer,
                            stored_map.tile_map.layers.len
                        );
                        for (0..tile_layers.len) |i|{
                            var chunk_map = std.AutoHashMapUnmanaged(
                                Coordinates,
                                RuntimeMap.TileMap.TileLayer.TileChunk
                            ).empty;
                            try chunk_map.ensureTotalCapacity(arena_allocator, 128);
                            // TODO maybe increase as time goes on. --------------------------------/\
                            for (stored_map.tile_map.layers[i].chunks) |chunk| {
                                try chunk_map.put(
                                    arena_allocator,
                                    chunk.getChunkCoord(),
                                    .{
                                        .tile_ids = try arena_allocator.dupe(i32, chunk.tile_ids),
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
                        try tile_property_list.ensureTotalCapacity(arena_allocator, 128);
                        // TODO maybe increase as time goes on. -----------------------------------------/\
                        for (stored_map.tile_map.tile_properties) |prop| {
                            try tile_property_list.put(
                                arena_allocator,
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
                        try collisions.ensureTotalCapacity(arena_allocator, 128);
                        for (stored_map.collision_map.collision_shapes) |rect| {
                            try collisions.put(
                                arena_allocator,
                                Coordinates.fromPosition(.{
                                    .x = rect.x,
                                    .y = rect.y,
                                }),
                                @bitCast(rect));
                        }
                        break :blk collisions;
                    },
                },
                .markers = blk: {
                    const marker_list = try arena_allocator.alloc(
                        Marker,
                        stored_map.markers.len
                    );
                    for (stored_map.markers, 0..) |m, i| {
                        marker_list[i] = .{
                            .x = m.x,
                            .y = m.y,
                            .kind = m.kind,
                            .name = try arena_allocator.dupe(u8, m.name),
                        };
                    }
                    break :blk marker_list;
                }
            };
        }
    };
}
