
pub var state: State = .menu;

const State = enum {
    menu,
    load_game,
    new_game,
    game,
    settings,
    pause,
    exit,
};
