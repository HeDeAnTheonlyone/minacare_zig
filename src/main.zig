const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const AnimationPlayer = @import("components.zig").AnimationPlayer;
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

    var update_dispatcher = event.Dispatcher(f32).init;

    var cerby = try Character.initTemplate(.Cerby);
    defer cerby.deinit();

    var map = try TileMap.init(gpa, "test", cerby.movement.pos);
    defer map.deinit(gpa);
    try cerby.movement.pos_changed_event.add(.{
        .func = TileMap.updateTileRenderCache,
        .ctx = &map,
    });

    var cam = rl.Camera2D{
        .target = cerby.movement.pos, 
        .offset = rl.Vector2{
            .x = @as(f32, @floatFromInt(@divFloor(settings.window_width, 2))) - settings.tile_size * settings.getResolutionRatio() / 2,
            .y = @as(f32, @floatFromInt(@divFloor(settings.window_height, 2))) - settings.tile_size * settings.getResolutionRatio() / 2,
        },
        .rotation = 0,
        .zoom = 1,
    };

    try update_dispatcher.add(.{
        .func = Character.update,
        .ctx = &cerby,
    });

    while(!rl.windowShouldClose())
    {
        if (rl.isKeyDown(.f11)) rl.toggleFullscreen();

        // Logic
        const delta = std.math.clamp(rl.getFrameTime(), 0, settings.frame_time_cap);
        try update_dispatcher.dispatch(delta);
        cam.target = cerby.movement.pos;
        // ===
        
        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.beginMode2D(cam);
        defer rl.endMode2D();
        
        rl.clearBackground(rl.Color.ray_white);

        map.draw();
        cerby.draw();
        rl.drawFPS(
            @as(i32, @intFromFloat(cerby.movement.pos.x)) - 50,
            @as(i32, @intFromFloat(cerby.movement.pos.y)) - 50
        );
        // ===
    }
}