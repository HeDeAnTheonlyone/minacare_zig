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

    try game_state.init();
    defer game_state.deinit(gpa);
    
    try game_state.map.loadMap(gpa, "test");

    /////////////////////////////////////////////////////////////////
    // All game_state values have to be initialized at this point. //
    /////////////////////////////////////////////////////////////////

    while(!rl.windowShouldClose())
    {
        try game_state.update();
        game_state.draw();
    }
}
