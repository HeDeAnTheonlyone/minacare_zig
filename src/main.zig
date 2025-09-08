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

    var player = try @import("Player.zig").init(
        try char_spawner.Cerby.spawn(
            spawn_pos.scale(settings.tile_size)
        )
    );
    
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
        try player.update(delta);
        try update_dispatcher.dispatch(delta);
        // <=== Logic
        
        // Drawing ===>
        rl.beginDrawing();
        defer rl.endDrawing();

        // >>> World space
        rl.beginMode2D(player.cam);
        
        rl.clearBackground(rl.Color.ray_white);

        game_state.map.draw();
        player.draw();
        rl.endMode2D();

        // >>> Screen space
        if (@import("builtin").mode == .Debug) {
            const debug = @import("debug.zig");
            debug.draw();
            if (debug.show_fps) drawer.drawFps(.{
                .x = 200,
                .y = 10,
            });
        }
        // <=== Drawing
    }

    game_state.deinit(gpa);
}
