const lib = @import("../lib.zig");
const game = lib.game;
const menu = game.menu;
const util = lib.util;
const event = util.event;

pub var current: State = .menu;
pub var last: State = .menu;
pub var counter: f32 = 0;
pub var events: struct {
    on_global_update: event.Dispatcher(f32, 16) = .init,
} = .{};

const State = enum {
    menu,
    load_game,
    new_game,
    game,
    settings,
    pause,
    exit,
};

pub fn switchTo(state: State) !void {
    if (state == current) return;
    last = current;
    switch(state) {
        .menu => |s| {current = s;}, 
        .load_game => {
            try game.state.loadGame(lib.app.gpa.allocator);
            current = .game;
        },
        .new_game => {
            try game.state.newGame(lib.app.gpa.allocator);
            current = .game;
        },
        .game => |s| {current = s;},
        .pause => |s| {current = s;},
        .settings => |s| {
            menu.settings.syncToSettings();
            current = s;
        },
        .exit => |s| {current = s;},
    }
}

// TODO if needed, add beforEnter/beforeExit functions for each state.
