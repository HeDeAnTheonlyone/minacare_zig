const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const tile_map = @import("tile_map.zig");
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const dispatcher = @import("dispatcher.zig");
const Character = @import("Character.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;

pub fn main() !void {
    const gpa = switch (@import("builtin").mode) {
        .Debug => debug_allocator.allocator(),
        else => std.heap.smp_allocator,
    };

    rl.initWindow(settings.window_width, settings.window_height, "Minacare");
    defer rl.closeWindow();
    rl.setTargetFPS(settings.target_fps);

    var update_dispatcher = dispatcher.CallbackDispatcher{};

    var map_file = try std.fs.cwd().openFile("assets/maps/test.zon", .{});
    var map = try tile_map.load(gpa, &map_file);
    defer map.deinit(gpa);
    map_file.close();

    var cerby = try Character.initTemplate(.Cerby);
    defer cerby.deinit();

    try update_dispatcher.add(.{
        .func = Character.updateCallbackAdapter,
        .ctx = &cerby,
    });

    while(!rl.windowShouldClose())
    {
        if (rl.isKeyDown(.space)) rl.toggleFullscreen();

        // Logic
        try update_dispatcher.dispatch(std.math.clamp(rl.getFrameTime(), 0, 0.05));
        // ===
        
        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.ray_white);

        rl.drawFPS(15, 15);
        cerby.draw();
    }
}