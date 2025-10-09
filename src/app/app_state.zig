const game = @import("../lib.zig").game;
const game_state = game.state;
const menu = game.menu;
const util = @import("../lib.zig").util;

pub var current: State = .menu;
pub var last: State = .menu;
pub var counter: f32 = 0;

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
            try game_state.loadGame();
            current = .game;
        },
        .new_game => {
            try game_state.newGame();
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

// TODO if needed, add bforeEnter/beforeExit functions for each state.
