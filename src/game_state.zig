//! `game_state` is only responsible to keep track of things during the game play and not the main menu.

const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const persistance = @import("persistance.zig");
const Allocator = @import("std").mem.Allocator;
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const Player = @import("Player.zig");
const char_spawner = @import("character_spawner.zig");
const TextBox = @import("TextBox.zig");

const Self = @This();
const character_spritehseet_path = "assets/textures/characters_spritesheet.png";
const tile_spritesheet_path = "assets/textures/tile_spritesheet.png";

/// A global counter for all kinds of stuff that needs it.
pub var counter: f32 = 0;
pub var map: TileMap = undefined;
pub var player: Player = undefined;
pub var text_box: TextBox = undefined;
pub var character_spritesheet: rl.Texture2D = undefined;
pub var tile_spritesheet: rl.Texture2D = undefined;
pub var events: struct {
    on_load: event.Dispatcher(void, 8),
    on_update: event.Dispatcher(f32,16),
    on_draw_world: event.Dispatcher(void, 16),
    on_draw_ui: event.Dispatcher(void, 16),
    on_exit: event.Dispatcher(void, 8),
} = undefined;
pub var paused: bool = false;

pub fn init() !void {
    character_spritesheet = try rl.loadTexture(character_spritehseet_path);
    tile_spritesheet = try rl.loadTexture(tile_spritesheet_path);
    events = .{
        .on_load = .init,
        .on_update = .init,
        .on_draw_world = .init,
        .on_draw_ui = .init,
        .on_exit = .init,
    };
    map = TileMap.init(&tile_spritesheet);
    try events.on_draw_world.add(.init(&map, "draw", 100));
    
    player = try Player.init(
        try char_spawner.Cerby.spawn(
            .{ .coordinates = .{
                .x = 0,
                .y = 40
            }}
        )
    );
    try events.on_load.add(.init(&player, "syncTransformation", 0));
    try events.on_update.add(.init(&player, "update", 0));
    try events.on_draw_world.add(.init(&player, "draw", 0));

    try player.char.movement.events.on_pos_changed.add(.init(&map, "updateTileRenderCache", 0));

    text_box = .init;
    try events.on_draw_ui.add(.init(&text_box, "draw", 0));
    try events.on_update.add(.init(&text_box, "update", 0));
    try text_box.events.on_popup.add(.init(Self, "pause", 0));
    try text_box.events.on_close.add(.init(Self, "unpause", 0));
}

pub fn deinit() void {
    save();
    events.on_exit.dispatch({}) catch unreachable;

    map.deinit();
    character_spritesheet.unload();
    tile_spritesheet.unload();
}

/// The games root update function
pub fn update(delta: f32) !void {
    counter += delta;
    try events.on_update.dispatch(delta);
}

/// The games root draw function
pub fn draw() !void {
    rl.beginMode2D(player.cam);
    events.on_draw_world.dispatch({}) catch unreachable;
    rl.endMode2D();
    
    events.on_draw_ui.dispatch({}) catch unreachable;

    if (@import("builtin").mode == .Debug) {
        const debug = @import("debug.zig");
        try debug.drawDebugPanel();
        // if (debug.show_fps) @import("drawer.zig").drawFps(.{
        //     .x = 200,
        //     .y = 10,
        // });
    }

    // DEBUG
    @import("drawer.zig").drawFps(.{
        .x = 200,
        .y = 10,
    });
}

/// Gets and loads save data if available.
fn load() !void {
    persistance.load(
        &player,
        .player,
    );

    if (@import("builtin").mode == .Debug) {
        persistance.load(
            @import("debug.zig"),
            .debug,
        );
    }

    try events.on_load.dispatch({});
}

/// Saves the current game state
fn save() void {
    persistance.save(&player, .player);
    if (@import("builtin").mode == .Debug) {
        persistance.save(@import("debug.zig"), .debug);
    }
}

/// Continue the game by loading the saved progress.
pub fn loadGame() !void {
    try load();
}

/// Delete progress and start game fresh.
pub fn newGame() !void {
    try persistance.delete();    
}

pub fn pause() !void {
    paused = true;
}

pub fn unpause() !void {
    paused = false;
}
