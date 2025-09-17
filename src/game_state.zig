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
pub var paused: bool = false;
pub var map: TileMap = undefined;
pub var player: Player = undefined;
pub var text_box: TextBox = undefined;
pub var character_spritesheet: rl.Texture2D = undefined;
pub var tile_spritesheet: rl.Texture2D = undefined;
pub var events: struct {
    on_update: event.Dispatcher(f32, 128),
    on_draw_world: event.Dispatcher(void, 128),
    on_draw_ui: event.Dispatcher(void, 128),
    on_exit: event.Dispatcher(void, 16),
} = undefined;


pub fn init(allocator: std.mem.Allocator) !void {
    character_spritesheet = try rl.loadTexture(character_spritehseet_path);
    tile_spritesheet = try rl.loadTexture(tile_spritesheet_path);
    events = .{
        .on_update = .init,
        .on_draw_world = .init,
        .on_draw_ui = .init,
        .on_exit = .init,
    };
    map = TileMap.init(&tile_spritesheet);
    try events.on_draw_world.add(.init(&map, "draw"));
    
    player = try Player.init(
        try char_spawner.Cerby.spawn(
            .{ .coordinates = .{
                .x = 0,
                .y = 40
            }}
        )
    );
    try events.on_update.add(.init(&player, "update"));
    try events.on_draw_world.add(.init(&player, "draw"));

    try player.char.movement.events.on_pos_changed.add(.init(&map, "updateTileRenderCache"));

    text_box = .init;
    try events.on_draw_ui.add(.init(&text_box, "draw"));
    try events.on_update.add(.init(&text_box, "update"));
    try text_box.events.on_popup.add(.init(Self, "pause"));
    try text_box.events.on_close.add(.init(Self, "unpause"));

    try load(allocator);
    try player.syncTransformation();

    // Do a single update to avoid visual glitches if the game gets instant paused.
    try update();

    //DEBUG Testing
    // try text_box.enqueuMessageList(&.{
    //     .{ .text = "Hello Minawan" },
    //     .{ .text = "And others," },
    //     .{ .text = "Progress is comming along nicely" },
    //     .{ .text = "just look at this cool textbox" },
    //     .{ .text = "Still nothing fancy" },
    //     .{ .text = "But it hope this will change soon." },
    //     .{ .text = "Testing line wrapping: jdsa dsaoid saodsapopüsaofgís9fdugj3wqk wq dwa ßds0ßdf0ßwa0ßfsad fsaß  sßdaodsakßüfgsdag asf f ß0pjsamfsamfsda fsa0fsaß fsa9fsaikfsak fsßf0isak fsajfnsaop igsmpgdfmgs fds gfdsnmgdfs pgfdsp gdnsoljkö lsddflasdsmgöds a öfsda sda dsa fspdjamg sgdpgpdskogpsd j öldsgö" },
    // });
}

pub fn deinit() void {
    map.deinit();
    character_spritesheet.unload();
    tile_spritesheet.unload();
}

fn load(allocator: std.mem.Allocator) !void {
    try persistance.load(
        allocator,
        settings,
        "settings",
    );

    try persistance.load(
        allocator,
        &player,
        "player",
    );

    if (@import("builtin").mode == .Debug) {
        try persistance.load(
            allocator,
            @import("debug.zig"),
            "debug",
        );
    }
}

fn save() !void {
    try persistance.save(&player, "player");
    try persistance.save(settings, "settings");
    if (@import("builtin").mode == .Debug) {
        try persistance.save(@import("debug.zig"), "debug");
    }
}

/// The games root update function
pub fn update() !void {
    const delta = std.math.clamp(
        rl.getFrameTime(),
        0,
        settings.frame_time_cap
    );

    counter += delta;
    try events.on_update.dispatch(delta);
}

/// The games root draw function
pub fn draw() !void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.black);

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

pub fn pause() !void {
    paused = true;
}

pub fn unpause() !void {
    paused = false;
}

pub fn exit() !void {
    try save();
    try events.on_exit.dispatch({});
}
