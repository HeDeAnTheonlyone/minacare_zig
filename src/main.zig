const std = @import("std");
const rl = @import("raylib");
const settings = @import("Settings.zig");
const AnimationPlayer = @import("components.zig").AnimationPlayer;
const dispatcher = @import("dispatcher.zig");
const Character = @import("Character.zig");
const Rectangle = rl.Rectangle;

pub fn main() !void {
    rl.initWindow(settings.window_width, settings.window_height, "Minacare");
    defer rl.closeWindow();
    rl.setTargetFPS(settings.target_fps);

    var update_dispatcher = dispatcher.CallbackDispatcher{};

    var cerby = try Character.initTemplate(.Cerby);
    defer cerby.deinit();

    try update_dispatcher.add(.{
        .func = Character.updateCallbackAdapter,
        .ctx = &cerby,
    });

    while(!rl.windowShouldClose())
    {
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