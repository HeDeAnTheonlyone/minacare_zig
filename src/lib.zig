pub const app = struct {
    pub const context = @import("app/app_context.zig");
    pub const state = @import("app/app_state.zig");
    pub const settings = @import("app/settings.zig");
};

pub const game = struct {
    pub const character_spawner = @import("game/character_spawner.zig");
    pub const Character = @import("game/Character.zig");
    pub const components = @import("game/components.zig");
    pub const state = @import("game/game_state.zig");
    pub const menu = @import("game/menu.zig");
    pub const Player = @import("game/Player.zig");
    pub const TextBox = @import("game/TextBox.zig");
    pub const TileMap = @import("game/TileMap.zig");
};

pub const util = struct {
    pub const debug = if (@import("builtin").mode == .Debug) @import("util/debug.zig");
    pub const drawer = @import("util/drawer.zig");
    pub const event = @import("util/event.zig");
    pub const persistance = @import("util/persistance.zig");
    pub const style = @import("util/style.zig");
    pub const translation = @import("util/translation.zig");
};