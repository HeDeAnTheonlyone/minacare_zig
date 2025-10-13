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
collision_map: CollisionMap = .init,
tile_render_cache: []TileDrawData = undefined,
background_tiles: []TileDrawData = undefined,
y_sorting_tiles: []TileDrawData = undefined,
y_sort_split_index: usize = 0,
current_chunk: ChunkCoordinates = Coordinates.splat(std.math.maxInt(i32)),
arena: ?std.heap.ArenaAllocator = null,

const Self = @This();
const concurrent_active_chunks = 9;
const tiles_per_chunk = std.math.powi(usize, @intCast(settings.chunk_size), 2) catch unreachable;

pub const Maps = enum {
    @"test",
    minaland,
};

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

pub fn drawBackground(self: *Self) !void {
    for (self.background_tiles) |draw_data| {
        drawer.drawTexturePro(
            self.texture.*,
            draw_data.source_rect,
            draw_data.dest_rect,
            Vector2.zero(),
            0,
            rl.Color.white
        );
    }

    const player_y = game_state.player.char.getBottomOffset();
    for (self.y_sorting_tiles) |draw_data| {
        if (
            draw_data.dest_rect.y +
            @as(f32, @floatFromInt(draw_data.properties.?.y_origin_offset.?)) >
            player_y
        ) continue;
            drawer.drawTexturePro(
                self.texture.*,
                getAnimationFrameSourceRect(draw_data),
                draw_data.dest_rect,
                Vector2.zero(),
                0,
                rl.Color.white
            );
    }
}

pub fn drawForeground(self: *Self) !void {
    const player_y = game_state.player.char.getBottomOffset();
    for (self.y_sorting_tiles) |draw_data| {
        if (
            draw_data.dest_rect.y +
            @as(f32, @floatFromInt(draw_data.properties.?.y_origin_offset.?)) <=
            player_y
        ) continue;
        drawer.drawTexturePro(
            self.texture.*,
            getAnimationFrameSourceRect(draw_data),
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
        var iter = self.collision_map.collisions.iterator();
        while (iter.next()) |collision_shape| {
            const pos = collision_shape.key_ptr
                .multiplyScalar(settings.tile_size)
                .toVector2();
            const rect = Rectangle{
                .x = collision_shape.value_ptr.*.x + pos.x,
                .y = collision_shape.value_ptr.*.y + pos.y,
                .width = collision_shape.value_ptr.*.width,
                .height = collision_shape.value_ptr.*.height,
            };
            drawer.drawRectOutline(
                rect,
                5,
                rl.Color.blue
            );
        }
    }
    
    if (debug.show_tile_layering) {
        const player_y = game_state.player.char.getBottomOffset();
        for (self.y_sorting_tiles) |tile| {
            const dest_rect = tile.dest_rect;
            drawer.drawRectOutline(
                dest_rect,
                3,
                if (
                    dest_rect.y +
                    @as(f32, @floatFromInt(tile.properties.?.y_origin_offset.?)) >
                    player_y
                ) rl.Color.dark_green
                else rl.Color.red,
            );
        }
    }
    
    if (debug.show_current_chunk_bounds) {
        const rect = getChunkRect(self.current_chunk);
        drawer.drawRectOutline(rect, 10, .purple);
    }
}

/// Returns the correct frame of the tile animation or just return the input if the tile has no animation.
fn getAnimationFrameSourceRect(draw_data: TileDrawData) Rectangle {
    if (draw_data.properties) |properties| {
        if (
            properties.frames != null and
            properties.frame_time != null
        ) {
            const sub_frame = @as(u32, @intFromFloat(@divFloor(
                game_state.counter * settings.base_framerate,
                @as(f32, @floatFromInt(properties.frame_time.?))
            )));
            const frame = @rem(sub_frame, properties.frames.?);
            const shift = frame * settings.tile_size;

            var tmp_source_rect = draw_data.source_rect;
            tmp_source_rect.shift(.x, @floatFromInt(shift));
            return tmp_source_rect;
        }
    }
    return draw_data.source_rect;
}

/// Deinits old map and load new map. `map_name` refers to the file name without the extension.
pub fn loadMap(self: *Self, allocator: std.mem.Allocator, map: Maps) !void {
    self.collision_map.collisions.deinit(allocator);
    if (self.arena != null) self.arena.?.deinit();
    
    self.arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = self.arena.?.allocator();

    self.map_data = try RuntimeMap.loadFromFile(
        arena_allocator,
        allocator,
        @tagName(map)
    );
    self.tile_render_cache = try allocator.alloc(
        TileDrawData,
        self.map_data.tile_map.layers.len * concurrent_active_chunks * tiles_per_chunk,
    );
    self.collision_map.collisions = .empty;
    try self.collision_map.collisions.ensureTotalCapacity(arena_allocator, 1024);
    try self.updateCache(game_state.player.char.movement.pos);
}

pub fn updateCache(self: *Self, player_pos: Vector2) !void {
    if (self.current_chunk.equals(getChunkCoordFromPos(player_pos))) return;
    self.current_chunk = getChunkCoordFromPos(player_pos);

    self.collision_map.collisions.clearRetainingCapacity();

    const allocator = self.arena.?.allocator();
    const cache_len = self.tile_render_cache.len;
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

    var background_tile_count: usize = 0;
    var y_sort_tile_count: usize = 0;
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

                const tile_properties = self.map_data.tile_map.tile_properties.getPtr(chunk.tile_ids[i]);
                const has_properties = tile_properties != null;

                if (has_properties and tile_properties.?.collision != null) {
                    try self.collision_map.collisions.put(
                        allocator,
                        Coordinates.fromPosition(.{.x = tile_dest_rect.x, .y = tile_dest_rect.y}),
                        &tile_properties.?.collision.?,
                    );
                }

                if (has_properties and tile_properties.?.y_origin_offset != null) {
                    y_sort_tile_count += 1;
                    self.tile_render_cache[cache_len - y_sort_tile_count] = .{
                        .source_rect = tile_source_rect,
                        .dest_rect = tile_dest_rect,
                        .properties = tile_properties,
                    };
                }
                else {
                    self.tile_render_cache[background_tile_count] = .{
                        .source_rect = tile_source_rect,
                        .dest_rect = tile_dest_rect,
                        .properties = tile_properties,
                    };
                    background_tile_count += 1;
                }
            }
        }
    }

    self.background_tiles = self.tile_render_cache[0..background_tile_count];
    self.y_sorting_tiles = self.tile_render_cache[cache_len - y_sort_tile_count..cache_len];

    std.mem.sort(
        TileDrawData,
        self.y_sorting_tiles,
        false,
        TileDrawData.lessThan
    );
}

const CollisionMap = struct {
    collisions: std.AutoHashMapUnmanaged(Coordinates, *Rectangle) = .empty,

    pub const init = CollisionMap{};

    pub fn getCollisionAtPos(self: *CollisionMap, player_pos: Vector2) ?Rectangle {
        const coords = Coordinates.fromPosition(player_pos);
        const snapped_pos = coords.multiplyScalar(settings.tile_size).toVector2();
        const collision_rect = self.collisions.get(coords);
        return if (collision_rect) |rect| Rectangle{
                .x = rect.x + snapped_pos.x,
                .y = rect.y + snapped_pos.y,
                .width = rect.width,
                .height = rect.height,
            }
            else null;
    }
};

const TileDrawData = struct {
    source_rect: Rectangle,
    dest_rect: Rectangle,
    properties: ?*RuntimeMap.TileMap.TileProperties,

    /// First parameter is necessary for std.mem.sort
    fn lessThan(descending: bool, self: TileDrawData, cmpr: TileDrawData) bool {
        return if (descending) self.dest_rect.y > cmpr.dest_rect.y
            else self.dest_rect.y < cmpr.dest_rect.y;
    } 
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
        markers: []Marker,

        pub const TileMap = struct {
            layers: []TileLayer,
            tile_properties: switch (value_container) {
                .Array => []TileProperties,
                .HashMap => std.AutoHashMapUnmanaged(i32, TileProperties),
            },

            pub const TileProperties = struct {
                id: i32,
                frames: ?u16 = null,
                frame_time: ?u16 = null,
                y_origin_offset: ?u16 = null,
                collision: ?Rectangle = null,
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

        pub const Marker = struct {
            x: i32,
            y: i32,
            kind: Kind,
            name: []const u8,

            pub const Kind = enum(u8) {
                checkpoint,
                spawnpoint,
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

            return try toRuntimeMap(arena_allocator, stored_map);
        }

        fn toRuntimeMap(arena_allocator: std.mem.Allocator, stored_map: StoredMap) !RuntimeMap {
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
                            // TODO increase as time goes on. --------------------------------------/\
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
                        var tile_property_map = std.AutoHashMapUnmanaged(
                            i32,
                            TileMap.TileProperties
                        ).empty;
                        try tile_property_map.ensureTotalCapacity(arena_allocator, 128);
                        // TODO increase as time goes on. ----------------------------------------------/\
                        for (stored_map.tile_map.tile_properties) |prop| {
                            try tile_property_map.put(
                                arena_allocator,
                                prop.id,
                                prop,
                            );
                        }
                        break :blk tile_property_map;
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
