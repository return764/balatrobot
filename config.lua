BALATRO_BOT_CONFIG = {
    enabled = true, -- Disables ALL mod functionality if false
    port = '12345', -- Port for the bot to listen on, overwritten by arg[1]
    dt = nil, -- Tells the game that every update is dt seconds long
    uncap_fps = false,
    instant_move = false,
    disable_vsync = false,
    disable_card_eval_status_text = true, -- e.g. +10 when scoring a queen
    frame_ratio = 1, -- Draw every 100th frame, set to 1 for normal rendering
}

return BALATRO_BOT_CONFIG