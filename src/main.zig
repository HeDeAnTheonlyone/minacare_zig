const std = @import("std");
const rl = @import("raylib");
const settings = @import("settings.zig");
const game_state = @import("game_state.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;
const gpa = switch (@import("builtin").mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};

pub fn main() !void {
    rl.initWindow(
        settings.window_width,
        settings.window_height,
        "Minacare"
    );
    defer rl.closeWindow();
    rl.setTargetFPS(settings.target_fps);

    try settings.init();
    defer settings.deinit();

    try game_state.init(gpa);
    defer game_state.deinit();
    
    try game_state.map.loadMap(gpa, "test");

    while(!rl.windowShouldClose())
    {
        try game_state.update();
        try game_state.draw();
    }
}
