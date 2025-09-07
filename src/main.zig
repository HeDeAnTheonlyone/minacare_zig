const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const GameState = @import("GameState.zig");
const drawer = @import("drawer.zig");
const event = @import("event.zig");
const TileMap = @import("TileMap.zig");
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const Character = @import("Character.zig");
const components = @import("components.zig");
var debug_allocator = std.heap.DebugAllocator(.{}).init;

pub fn main() !void {
    settings.init();

    const gpa = switch (@import("builtin").mode) {
        .Debug => debug_allocator.allocator(),
        else => std.heap.smp_allocator,
    };

    rl.initWindow(settings.window_width, settings.window_height, "Minacare");
    defer rl.closeWindow();
    rl.setTargetFPS(settings.target_fps);

    var update_dispatcher = event.Dispatcher(f32).init;

    const spawn_pos = rl.Vector2{.x = 0, .y = 40};

    GameState.map = try TileMap.init(gpa, "test", spawn_pos);

    var cerby = try Character.initTemplate(
        .Cerby,
        spawn_pos.scale(settings.tile_size)
    );
    defer cerby.deinit();

    try cerby.movement.pos_changed_event.add(.{
        .func = TileMap.updateTileRenderCache,
        .ctx = &GameState.map,
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
        .func = Character.update,
        .ctx = &cerby,
    });
    
    // All GameState values have to be initialized at this point.

    while(!rl.windowShouldClose())
    {
        if (rl.isKeyDown(.f11)) rl.toggleFullscreen();

        // Logic
        const delta = std.math.clamp(rl.getFrameTime(), 0, settings.frame_time_cap);
        try update_dispatcher.dispatch(delta);
        cam.target = cerby.movement.pos.scale(settings.resolution_ratio);
        // ===
        
        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.beginMode2D(cam);
        defer rl.endMode2D();
        
        rl.clearBackground(rl.Color.ray_white);

        GameState.map.draw();
        cerby.draw();
        if (@import("builtin").mode == .Debug) {
            drawer.drawFps(cerby.movement.pos.subtractValue(8));
        }
        // ===
    }

    GameState.deinit(gpa);
}
