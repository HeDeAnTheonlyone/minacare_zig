
//! Intermediate type for storing/loading map data in/from a file

tile_map: TileMap,
collision_map: CollisionMap,
markers: []const Marker,

pub const TileMap = struct {
    layers: []const TileLayer,

    pub const TileLayer = struct {
        chunks: []const TileChunk,
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
    collision_shapes: []CollisionMapEntry,
    
    pub const CollisionMapEntry = struct {
        key: Vector2,
        value: Rectangle,

        pub const Vector2 = packed struct {
            x: f32,
            y: f32,
        };

        pub const Rectangle = packed struct {
            x: f32,
            y: f32,
            width: f32,
            height: f32,
        };
    };
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