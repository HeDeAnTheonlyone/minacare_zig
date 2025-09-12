const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const Allocator = @import("std").mem.Allocator;
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const Player = @import("Player.zig");
const char_spawner = @import("character_spawner.zig");

const character_spritehseet_path = "assets/textures/characters_spritesheet.png";
const tile_spritesheet_path = "assets/textures/tile_spritesheet.png";

/// A global counter for all kinds of stuff that needs it.
pub var counter: f32 = 0;
pub var map: TileMap = undefined;
pub var player: Player = undefined;
pub var character_spritesheet: rl.Texture2D = undefined;
pub var tile_spritesheet: rl.Texture2D = undefined;
pub var events: struct {
    on_update: event.Dispatcher(f32),
    on_draw_world: event.Dispatcher(void),
    on_draw_ui: event.Dispatcher(void),
} = undefined;


pub fn init() !void {
    character_spritesheet = try rl.loadTexture(character_spritehseet_path);
    tile_spritesheet = try rl.loadTexture(tile_spritesheet_path);
    events = .{
        .on_update = .init,
        .on_draw_world = .init,
        .on_draw_ui = .init,
    };
    map = TileMap.init(&tile_spritesheet);
    try events.on_draw_world.add(.{
        .func = event.createDrawCallbackAdapter(TileMap),
        .ctx = &map
    });
    
    player = try Player.init(
        try char_spawner.Cerby.spawn(
            .{ .coordinates = .{
                .x = 0,
                .y = 40
            }}
        )
    );
    try events.on_update.add(.{
        .func = event.createUpdateCallbackAdapter(Player),
        .ctx = &player
    });
    try events.on_draw_world.add(.{
        .func = event.createDrawCallbackAdapter(Player),
        .ctx = &player
    });

    try player.char.movement.events.on_pos_changed.add(.{
        .func = TileMap.updateTileRenderCacheCallback,
        .ctx = &map
    });
}

pub fn deinit(allocator: Allocator) void {
    map.deinit(allocator);
    character_spritesheet.unload();
    tile_spritesheet.unload();
}

pub fn update() !void {
    const delta = std.math.clamp(
        rl.getFrameTime(),
        0,
        settings.frame_time_cap
    );

    counter += delta;
    try events.on_update.dispatch(delta);
}

pub fn draw() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.beginMode2D(player.cam);
    events.on_draw_world.dispatch({}) catch unreachable;
    rl.endMode2D();
    
    events.on_draw_ui.dispatch({}) catch unreachable;

    if (@import("builtin").mode == .Debug) {
        const debug = @import("debug.zig");
        debug.drawDebugPanel();
        if (debug.show_fps) @import("drawer.zig").drawFps(.{
            .x = 200,
            .y = 10,
        });
    }
}
