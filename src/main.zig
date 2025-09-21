const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const game_state = @import("game_state.zig");
const Menu = @import("Menu.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;
const gpa = switch (@import("builtin").mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(
        settings.window_width,
        settings.window_height,
        "Minacare"
    );
    defer rl.closeWindow();

    try settings.init();
    defer settings.deinit();

    rl.setTargetFPS(settings.target_fps);

    try game_state.init(gpa);
    defer game_state.deinit();
    
    // DEBUG switch out for real map later
    try game_state.map.loadMap(gpa, "test");

    while(!rl.windowShouldClose())
    {
        // DEBUG start
        if(rl.isWindowResized()) {
            settings.changeResolution(
                rl.getRenderWidth(),
                rl.getRenderHeight()
            );

            game_state.player.recenter();
        }

        if (rl.isKeyPressed(.f6)) {
            rl.toggleBorderlessWindowed();
            std.debug.print("{any}, {any}\n", .{rl.getScreenWidth(), rl.getRenderWidth()});

            settings.changeResolution(
                rl.getRenderWidth(),
                rl.getRenderHeight()
            );

            game_state.player.recenter();
        }
        // DEBUG end

        try game_state.update();
        try game_state.draw();

        // Menu.draw();
    }
}
