const std = @import("std");
const rl = @import("raylib");
const cfg = @import("config.zig").Config;
const animation = @import("animation.zig");
const signals = @import("signals.zig");
const manager = @import("manager.zig");
const Minawan = @import("minawan.zig").Minawan;
const Rectangle = rl.Rectangle;
const smp = std.heap.smp_allocator;
const ArrayList = std.ArrayList;

pub fn main() !void {
    rl.initWindow(cfg.window_width, cfg.window_height, "Minacare");
    defer rl.closeWindow();
    rl.setTargetFPS(cfg.target_fps);

    var update_manager = manager.UpdateManager{
        .update_list = ArrayList(signals.Callback).init(smp)
    };

    const minawan_texture = try rl.loadTexture("assets/textures/minawan/mina_gyat_spritesheet.png");
    defer rl.unloadTexture(minawan_texture);

    var minawan_character = Minawan.init(
        animation.AnimationPlayer.init(
            minawan_texture,
            512,
            256,
            5,
            23
        )
    );

    try update_manager.addCallback(signals.Callback{
        .func = Minawan.updateCallbackAdapter,
        .ctx = &minawan_character,
    });

    while(!rl.windowShouldClose())
    {
        // Logic
        try update_manager.update(std.math.clamp(rl.getFrameTime(), 0, 0.05));
        // ===
        
        // Drawing
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.ray_white);

        rl.drawFPS(15, 15);
        
        minawan_character.draw();
    }
}