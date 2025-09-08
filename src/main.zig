const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const game_state = @import("game_state.zig");
const drawer = @import("drawer.zig");
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const Character = @import("Character.zig");
const char_spawner = @import("character_spawner.zig");
const components = @import("components.zig");
const debug = @import("debug.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;

pub fn main() !void {
    const gpa = switch (@import("builtin").mode) {
        .Debug => debug_allocator.allocator(),
        else => std.heap.smp_allocator,
    };

    rl.initWindow(
        settings.window_width,
        settings.window_height,
        "Minacare"
    );
    defer rl.closeWindow();
    rl.setTargetFPS(settings.target_fps);

    try settings.init();
    defer settings.deinit();

    game_state.character_spritesheet = try rl.loadTexture("assets/textures/characters_spritesheet.png");

    var update_dispatcher = event.Dispatcher(f32).init;

    const spawn_pos = rl.Vector2{.x = 0, .y = 40};

    game_state.map = try TileMap.init(
        gpa,
        "test",
        spawn_pos
    );

    var cerby = try char_spawner.Cerby.spawn(
        spawn_pos.scale(settings.tile_size)
    );

    try cerby.movement.events.pos_changed.add(.{
        .func = TileMap.updateTileRenderCacheCallback,
        .ctx = &game_state.map,
    });

    var cam = rl.Camera2D{
        .target = cerby.movement.pos.scale(settings.resolution_ratio), 
        .offset = rl.Vector2{
            .x = @as(f32, @floatFromInt(@divFloor(settings.window_width, 2))) - settings.tile_size / 2,
            .y = @as(f32, @floatFromInt(@divFloor(settings.window_height, 2))) - settings.tile_size / 2,
        },
        .rotation = 0,
        .zoom = 1,
    };

    try update_dispatcher.add(.{
        .func = Character.updateCallback,
        .ctx = &cerby,
    });
    
    /////////////////////////////////////////////////////////////////
    // All game_state values have to be initialized at this point. //
    /////////////////////////////////////////////////////////////////

    while(!rl.windowShouldClose())
    {
        // Logic ===> 
        const delta = std.math.clamp(
            rl.getFrameTime(),
            0,
            settings.frame_time_cap
        );
        try update_dispatcher.dispatch(delta);
        cam.target = cerby.movement.pos.scale(settings.resolution_ratio);
        // <=== Logic
        
        // Drawing ===>
        rl.beginDrawing();
        defer rl.endDrawing();

        // >>> World space
        rl.beginMode2D(cam);
        
        rl.clearBackground(rl.Color.ray_white);

        game_state.map.draw();
        cerby.draw();
        if (@import("builtin").mode == .Debug) {
            drawer.drawFps(cerby.movement.pos.subtractValue(8));
        }
        rl.endMode2D();

        // >>> Screen space
        debug.draw();
        // <=== Drawing
    }

    game_state.deinit(gpa);
}
