const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const TileMap = @import("TileMap.zig");
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

    var update_dispatcher = dispatcher.CallbackDispatcher.init;

    var map = try TileMap.init(gpa, "test");
    defer map.deinit(gpa);

    var cerby = try Character.initTemplate(.Cerby);
    defer cerby.deinit();

    var cam = rl.Camera2D{
        .target = cerby.movement.pos, 
        .offset = rl.Vector2{
            .x = @as(f32, @floatFromInt(@divFloor(settings.window_width, 2))) - settings.tile_size * settings.getRsolutionRatio() / 2,
            .y = @as(f32, @floatFromInt(@divFloor(settings.window_height, 2))) - settings.tile_size * settings.getRsolutionRatio() / 2,
        },
        .rotation = 0,
        .zoom = 1,
    };

    try update_dispatcher.add(.{
        .func = Character.updateCallbackAdapter,
        .ctx = &cerby,
    });

    while(!rl.windowShouldClose())
    {
        if (rl.isKeyDown(.space)) rl.toggleFullscreen();

        // Logic
        try update_dispatcher.dispatch(std.math.clamp(rl.getFrameTime(), 0, 0.05));
        cam.target = cerby.movement.pos;
        std.debug.print("{any}\n", .{cerby.movement.pos});
        // ===
        
        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.beginMode2D(cam);
        defer rl.endMode2D();
        rl.clearBackground(rl.Color.ray_white);

        rl.drawFPS(
            @as(i32, @intFromFloat(cerby.movement.pos.x)) - 50,
            @as(i32, @intFromFloat(cerby.movement.pos.y)) - 50
        );
        try map.draw(cerby.movement.pos);
        cerby.draw();
    }
}