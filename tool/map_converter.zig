const std = @import("std");
const rl = @import("raylib").raylib_module;
const settings = @import("../src/app/settings.zig");
const StoredMap = @import("../src/game/TileMap.zig").StoredMap;

/// Intermediate types for the data cleanup and conversion
const tiled_types = struct {
    const MapData = struct {
        allocator: std.mem.Allocator,
        tile_layers: []TileLayer,
        special_tile_list: *SpecialTileList,
        collision_layer: *CollisionLayer,
        marker_layer: *MarkerLayer,

        fn init(allocator: std.mem.Allocator, layer_count: usize) !MapData {
            return MapData{
                .allocator = allocator,
                .tile_layers = try allocator.alloc(TileLayer, layer_count),
                .special_tile_list = try allocator.create(SpecialTileList),
                .marker_layer = try allocator.create(MarkerLayer),
                .collision_layer = try allocator.create(CollisionLayer),
            };
        }
    };

    const SpecialTileList = struct {
        tiles: []TilePropertyList,
    };

    const TilePropertyList = struct {
        id: u32,
        properties: []TileProperty,
    };

    const TileProperty = struct {
        value: u8,
        name: []const u8,
    };

    const TileChunk = struct {
        data: []const u32,
        x: i32,
        y: i32,
    };

    const TileLayer = struct {
        chunks: []TileChunk,
        startx: i32,
        starty:i32, 
        width: u32, // measured in tiles
        height: u32, // measured in tiles
        name: []const u8,
    };

    const RectObj = struct {
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    };

    const CollisionLayer = struct {
        objects: []RectObj,
    };

    const PointObj = struct {
        x: i32,
        y: i32,
        name: []const u8,
        @"type": []const u8,
    };

    const MarkerLayer = struct {
        objects: []PointObj,
    };
};

pub fn start() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    const arena_allocator = arena.allocator();
    defer arena.deinit();

    var dev_maps_dir = try std.fs.cwd().openDir("assets/dev_maps", .{.iterate = true});
    defer dev_maps_dir.close();

    var maps_dir = try std.fs.cwd().openDir("assets/maps", .{});
    defer maps_dir.close();

    var maps_iter = dev_maps_dir.iterate();

    while (try maps_iter.next()) |m| {
        switch (m.kind) {
            .file => {
                const file = try dev_maps_dir.openFile(m.name, .{});
                var file_reader = file.reader(&.{});
                var json_str = std.io.Writer.Allocating.init(arena_allocator);
                defer json_str.deinit();
                _ = try std.Io.Reader.streamRemaining(&file_reader.interface, &json_str.writer);

                const map_data = try parseData(arena_allocator, json_str.written());
                const converted_map_data = try convertMap(arena_allocator, map_data);

                const converted_map_file = try maps_dir.createFile(
                    try std.mem.concat(
                        arena_allocator,
                        u8,
                        &.{m.name[0..m.name.len - 4], ".zon"}
                    ),
                    .{}
                );
                defer converted_map_file.close();

                var file_writer = converted_map_file.writer(&.{});

                try std.zon.stringify.serialize(
                    converted_map_data,
                    .{.whitespace = false},
                    &file_writer.interface
                );
            },
            else => continue,
        }
    }
}

/// Caller owns returned memory.
fn parseData(allocator: std.mem.Allocator, json_str: []const u8) !tiled_types.MapData {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_str,
        .{}
    );
    
    const p_layers = parsed.value.object.get("layers").?.array.items;

    var map_data = try tiled_types.MapData.init(
        allocator,
        p_layers.len - 2,
    );
    
    try extractRelevantMapData(
        tiled_types.SpecialTileList,
        allocator,
        parsed.value.object.get("tilesets").?.array.items[0],
        map_data.special_tile_list,
    );
    
    var tile_layer_count: u8 = 0;

    for (p_layers) |entry| {
        const @"type" = entry.object.get("type").?.string;
        
        if (std.mem.eql(u8, @"type", "tilelayer")) {
            try extractRelevantMapData(
                tiled_types.TileLayer,
                allocator,
                entry,
                &map_data.tile_layers[tile_layer_count],
            );
            tile_layer_count += 1;
        }
        else if (std.mem.eql(u8, @"type", "objectgroup")) {
            const name = entry.object.get("name").?.string;

            if (std.mem.eql(u8, name, "marker")) {
                try extractRelevantMapData(
                    tiled_types.MarkerLayer,
                    allocator,
                    entry,
                    map_data.marker_layer
                );
            }
            else if (std.mem.eql(u8, name, "collisions")) {
                try extractRelevantMapData(
                    tiled_types.CollisionLayer,
                    allocator,
                    entry,
                    map_data.collision_layer
                );
            }
        }
    }

    return map_data;
}

fn extractRelevantMapData(T: type, allocator: std.mem.Allocator, json_value: std.json.Value, ptr: *T) !void {
    const parsed = try std.json.parseFromValue(
        T,
        allocator,
        json_value,
        .{.ignore_unknown_fields = true, }
    );
    ptr.* = parsed.value;
}

fn convertMap(allocator: std.mem.Allocator, map_data: tiled_types.MapData) !StoredMap {
    return .{
        .tile_map = .{
            .layers = outer_blk: {
                var layers = try allocator.alloc(StoredMap.TileMap.TileLayer, map_data.tile_layers.len);
                for (0..layers.len) |i| {
                    layers[i] = middle_blk: {
                        const tile_layer = map_data.tile_layers[i];
                        const layer = StoredMap.TileMap.TileLayer{
                            .chunks = inner_blk: {
                                var chunks = try allocator.alloc(StoredMap.TileMap.TileLayer.TileChunk, tile_layer.chunks.len);
                                for (0..tile_layer.chunks.len) |j| {
                                    chunks[j] = StoredMap.TileMap.TileLayer.TileChunk{
                                        .tile_ids = blk: {
                                            const list: []i32 = @constCast(@as([]const i32, @alignCast(@ptrCast(tile_layer.chunks[j].data))));
                                            for (list) |*id| {
                                                id.* -= 1;
                                            }
                                            break :blk list;
                                        },
                                        .x = tile_layer.chunks[j].x,
                                        .y = tile_layer.chunks[j].y,
                                    };
                                }
                                break :inner_blk chunks;
                            },
                            // .x = tile_layer.startx,
                            // .y = tile_layer.starty,
                            // .width = tile_layer.width,
                            // .height = tile_layer.height,
                            // .name = tile_layer.name, 
                        };
                        break :middle_blk layer;
                    };
                }
                break :outer_blk layers;
            },
            .tile_properties = outer_blk: {
                const tiles = map_data.special_tile_list.tiles;
                var properties = try allocator.alloc(StoredMap.TileMap.TileProperties, tiles.len);

                for(0..tiles.len) |i| {
                    properties[i] = inner_blk: {
                        var property = StoredMap.TileMap.TileProperties{
                            .id = @intCast(tiles[i].id),
                        };
                        for (tiles[i].properties) |p| {
                            inline for (comptime std.meta.fieldNames(StoredMap.TileMap.TileProperties)) |field| {
                                if (std.mem.eql(u8, field, p.name))
                                @field(property, field) = p.value;
                            }
                        }
                        break :inner_blk property;
                    };
                }
                break :outer_blk properties;
            }
        },
        .collision_map = .{
            .collision_shapes = blk: {
                const col_objs = map_data.collision_layer.objects;
                var collisions = try allocator.alloc(
                    rl.Rectangle,
                    col_objs.len
                );
                for (0..collisions.len) |i| {
                    collisions[i] = rl.Rectangle{
                        .x = @floatFromInt(col_objs[i].x),
                        .y = @floatFromInt(col_objs[i].y),
                        .width = @floatFromInt(col_objs[i].width),
                        .height = @floatFromInt(col_objs[i].height),
                    };
                }
                break :blk collisions;
            }
        },
        .markers = blk: {
            var markers = try allocator.alloc(StoredMap.Marker, map_data.marker_layer.objects.len);
            for (0..markers.len) |i| {
                const point_obj = map_data.marker_layer.objects;
                markers[i] = StoredMap.Marker{
                    .x = point_obj[i].x,
                    .y = point_obj[i].y,
                    .kind = std.meta.stringToEnum(StoredMap.Marker.Kind, point_obj[i].@"type").?,
                    .name = point_obj[i].name,
                };
            }
            break :blk markers;
        }
    };
}
