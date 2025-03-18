local socket = require "socket"

local data, msg_or_ip, port_or_nil

BalatrobotAPI = { }
BalatrobotAPI.socket = nil
BalatrobotAPI.last_state = nil

BalatrobotAPI.waitingFor = nil
BalatrobotAPI.waitingForAction = false

-- 完整的动作定义
BalatrobotAPI.ACTIONS = {
    GET_GAMESTATE = 0,
    SELECT_BLIND = 1,
    SKIP_BLIND = 2,
    PLAY_HAND = 3,
    DISCARD_HAND = 4,
    END_SHOP = 5,
    REROLL_SHOP = 6,
    BUY_CARD = 7,
    BUY_VOUCHER = 8,
    BUY_BOOSTER = 9,
    SELECT_BOOSTER_CARD = 10,
    SKIP_BOOSTER_PACK = 11,
    SELL_JOKER = 12,
    USE_CONSUMABLE = 13,
    SELL_CONSUMABLE = 14,
    REARRANGE_JOKERS = 15,
    REARRANGE_CONSUMABLES = 16,
    REARRANGE_HAND = 17,
    PASS = 18,
    START_RUN = 19,
    CASH_OUT = 20
}

-- 完整的动作参数定义
BalatrobotAPI.ACTIONPARAMS = {
    [BalatrobotAPI.ACTIONS.START_RUN] = {
        num_args = 4,
        func = "c_start_run",
        isvalid = function(action)
            if G and G.STATE == G.STATES.MENU then
                return true
            end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.SELECT_BLIND] = {
        num_args = 0,
        func = "c_select_blind",
        isvalid = function(action)
            if G.STATE == G.STATES.BLIND_SELECT then return true end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.SKIP_BLIND] = {
        num_args = 0,
        func = "c_skip_blind",
        isvalid = function(action)
            if G.STATE == G.STATES.BLIND_SELECT then return true end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.PLAY_HAND] = {
        num_args = 1,
        func = "c_play_hand",
        isvalid = function(action)
            if G and G.GAME and G.GAME.current_round and G.hand and G.hand.cards and
                G.GAME.current_round.hands_left > 0 and
                Utils.isTableInRange(action[1], 1, #G.hand.cards) and
                Utils.isTableUnique(action[1]) then
                return true
            end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.DISCARD_HAND] = {
        num_args = 1,
        func = "c_discard_hand",
        isvalid = function(action)
            if G and G.GAME and G.GAME.current_round and G.hand and G.hand.cards and
                G.GAME.current_round.hands_left > 0 and
                Utils.isTableInRange(action[1], 1, #G.hand.cards) and
                Utils.isTableUnique(action[1]) then
                return true
            end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.SELL_JOKER] = {
        num_args = 1,
        func = "c_sell_jokers",
        isvalid = function(action)
            if G and G.jokers and G.jokers.cards then
                if Utils.isTableInRange(action[1], 1, #G.jokers.cards)then
                    return true
                end
            end
            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.BUY_CARD] = {
        num_args = 1,
        func = "c_buy_card",
        isvalid = function(action)
            local cards = action[1]
            if not G 
                or G.STATE ~= G.STATES.SHOP 
                or not G.shop_jokers 
                or not G.shop_jokers.cards
            then
                return false
            end
            if not Utils.isTableInRange(cards, 1, #G.shop_jokers.cards)then
                return false
            end
            local cost = 0
            for _, value in ipairs(cards) do
                cost = G.shop_jokers.cards[value].cost + cost
            end
            if cost > G.GAME.dollars then
                return false
            end
            return true
        end,
    },
    [BalatrobotAPI.ACTIONS.BUY_VOUCHER] = {
        num_args = 1,
        func = "c_buy_vouchers",
        isvalid = function(action)
            local cards = action[1]
            if not G 
                or G.STATE ~= G.STATES.SHOP 
                or not G.shop_vouchers 
                or not G.shop_vouchers.cards
            then
                return false
            end
            if not Utils.isTableInRange(cards, 1, #G.shop_vouchers.cards)then
                return false
            end
            local cost = 0
            for _, value in ipairs(cards) do
                cost = G.shop_vouchers.cards[value].cost + cost
            end
            if cost > G.GAME.dollars then
                return false
            end
            return true
        end,
    },
    [BalatrobotAPI.ACTIONS.BUY_BOOSTER] = {
        num_args = 1,
        func = "c_buy_booster",
        isvalid = function(action)
            local index = action[1]
            if not G 
                or G.STATE ~= G.STATES.SHOP 
                or not G.shop_booster 
                or not G.shop_booster.cards
                or index > #G.shop_booster.cards
            then
                return false
            end

            if G.shop_booster.cards[index].cost > G.GAME.dollars then
                return false
            end
            return true
        end,
    },
    [BalatrobotAPI.ACTIONS.SELECT_BOOSTER_CARD] = {
        num_args = 2,
        func = "c_choose_booster_cards",
        isvalid = function(action)
            local indexes = action[1]
            local use_indexes = action[2]
            local hand_card_condition = G.hand and G.hand.cards and Utils.isTableInRange(use_indexes, 1, #G.hand.cards) and Utils.isTableUnique(use_indexes)
            local booster_card_condition = G.pack_cards and G.pack_cards.cards and Utils.isTableInRange(indexes, 1, #G.pack_cards.cards) and Utils.isTableUnique(indexes)
            if G and hand_card_condition 
            and booster_card_condition 
            and SMODS.OPENED_BOOSTER
            then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.SKIP_BOOSTER_PACK] = {
        num_args = 0,
        func = "c_skip_booster",
        isvalid = function()
            if Middleware.BUTTONS.SKIP_PACK then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.REROLL_SHOP] = {
        num_args = 0,
        func = "c_reroll_shop",
        isvalid = function()
            if Middleware.BUTTONS.REROLL 
            and Middleware.BUTTONS.REROLL.config 
            and Middleware.BUTTONS.REROLL.config.button then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.END_SHOP] = {
        num_args = 0,
        func = "c_end_shop",
        isvalid = function()
            if G.STATE == G.STATES.SHOP and G.shop then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.USE_CONSUMABLE] = {
        num_args = 2,
        func = "c_use_consumable_card",
        isvalid = function(action)
            local consumable_indexes = action[1]
            local hand_card_indexes = action[2]

            local consumable_card_condition = G.consumeables and G.consumeables.cards and Utils.isTableInRange(consumable_indexes, 1, #G.consumeables.cards) and Utils.isTableUnique(consumable_indexes)
            if G and consumable_card_condition then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.SELL_CONSUMABLE] = {
        num_args = 1,
        func = "c_sell_consumable_card",
        isvalid = function(action)
            local consumable_indexes = action[1]

            local consumable_card_condition = G.consumeables and G.consumeables.cards and Utils.isTableInRange(consumable_indexes, 1, #G.consumeables.cards) and Utils.isTableUnique(consumable_indexes)
            if G and consumable_card_condition then
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.REARRANGE_JOKERS] = {
        num_args = 1,
        func = "c_rearrange_jokers",
        isvalid = function(action)
            local order = action[1]

            if order or #order == #G.jokers.cards then 
                return true
            end

            return false
        end,
    },
    [BalatrobotAPI.ACTIONS.CASH_OUT] = {
        num_args = 0,
        func = "c_cash_out",
        isvalid = function()
            if G and G.STATE == G.STATES.ROUND_EVAL and G.round_eval and Middleware.BUTTONS.CASH_OUT then 
                return true
            end

            return false
        end,
    }
}

function BalatrobotAPI.notifyapiclient()
    -- 只在状态改变时发送通知
    local _gamestate = Utils.getGamestate()
    -- if BalatrobotAPI.last_state ~= _gamestate.state then
    --     BalatrobotAPI.last_state = _gamestate.state
    -- end
    _gamestate.waitingFor = BalatrobotAPI.waitingFor
    _gamestate.waitingForAction = BalatrobotAPI.waitingFor ~= nil and BalatrobotAPI.waitingForAction or false
    local _gamestateJsonString = json.encode(_gamestate)

    if BalatrobotAPI.socket and port_or_nil ~= nil then
        sendDebugMessage(_gamestateJsonString)
        BalatrobotAPI.socket:sendto(string.format("%s", _gamestateJsonString), msg_or_ip, port_or_nil)
    end
end

function BalatrobotAPI.respond(str)
    sendDebugMessage('respond'..str)
    if BalatrobotAPI.socket and port_or_nil ~= nil then
        response = { }
        response.response = str
        str = json.encode(response)
        BalatrobotAPI.socket:sendto(string.format("%s\n", str), msg_or_ip, port_or_nil)
    end
end

function BalatrobotAPI.executeAction(action)
    local _params = BalatrobotAPI.ACTIONPARAMS[action[1]]
    if _params and _params.func then
        -- 创建事件直接执行 Middleware 函数
        local _event = Event({
            trigger = 'after',
            delay = 0,
            blocking = false,
            func = function()
                table.remove(action, 1)
                Middleware[_params.func](unpack(action))
                return true
            end
        })
        G.E_MANAGER:add_event(_event)
    end
end

function BalatrobotAPI.update(dt)

    if not BalatrobotAPI.waitingForAction then
        local any_thing_could_do = {"SELL_CONSUMABLE", "SELL_JOKER", "REARRANGE_JOKERS"}

        if G.STATE == G.STATES.MENU then
            BalatrobotAPI.waitingFor = {"START_RUN"}
            BalatrobotAPI.waitingForAction = true
        end

        if G.STATE == G.STATES.BLIND_SELECT then
            BalatrobotAPI.waitingFor = {"SELECT_BLIND", "SKIP_BLIND", unpack(any_thing_could_do)}
            BalatrobotAPI.waitingForAction = true
        end

        if G.STATE == G.STATES.SELECTING_HAND then
            BalatrobotAPI.waitingFor = {"PLAY_HAND", "DISCARD_HAND", unpack(any_thing_could_do)}
            BalatrobotAPI.waitingForAction = true
        end

        if G.STATE == G.STATES.NEW_ROUND then
            BalatrobotAPI.waitingFor = {"CASH_OUT"}
            BalatrobotAPI.waitingForAction = true
        end

        if G.STATE == G.STATES.SHOP then
            BalatrobotAPI.waitingFor = {
                "END_SHOP",
                "REROLL_SHOP", 
                "BUY_BOOSTER",
                "BUY_CARD",
                "BUY_VOUCHER",
                unpack(any_thing_could_do)
            }
            BalatrobotAPI.waitingForAction = true
        end

        if G.STATE == G.STATES.SMODS_BOOSTER_OPENED then
            BalatrobotAPI.waitingFor = {
                "SELECT_BOOSTER_CARD",
                "USE_CONSUMABLE",
                unpack(any_thing_could_do)
            }
            BalatrobotAPI.waitingForAction = true
        end

        BalatrobotAPI.notifyapiclient()
    end

    if not BalatrobotAPI.socket then
        sendDebugMessage('new socket')
        BalatrobotAPI.socket = socket.udp()
        BalatrobotAPI.socket:settimeout(0)
        local port = BALATRO_BOT_CONFIG.port
        BalatrobotAPI.socket:setsockname('127.0.0.1', tonumber(port))
    end

    data, msg_or_ip, port_or_nil = BalatrobotAPI.socket:receivefrom()

    if data then
        local _action = Utils.parseaction(data)
        if _action and _action[1] == BalatrobotAPI.ACTIONS.GET_GAMESTATE then
            BalatrobotAPI.notifyapiclient()
            return
        end
        local _err = Utils.validateAction(_action)

        if _err == Utils.ERROR.NUMPARAMS then
            BalatrobotAPI.respond("Error: Incorrect number of params for action " .. _action[1])
        elseif _err == Utils.ERROR.MSGFORMAT then
            BalatrobotAPI.respond("Error: Incorrect message format. Should be ACTION|arg1|arg2")
        elseif _err == Utils.ERROR.INVALIDACTION then
            BalatrobotAPI.respond("Error: Action invalid for action " .. _action[1])
        else
            BalatrobotAPI.waitingForAction = false
            -- 直接执行动作而不是加入队列
            BalatrobotAPI.executeAction(_action)
        end
    elseif msg_or_ip ~= 'timeout' then
        sendDebugMessage("Unknown network error: "..tostring(msg))
    end
end

function BalatrobotAPI.init()
    love.update = Hook.addcallback(love.update, BalatrobotAPI.update)
    G.F_SKIP_TUTORIAL = true

    -- Tell the game engine that every frame is 8/60 seconds long
    -- Speeds up the game execution
    -- Values higher than this seem to cause instability
    if BALATRO_BOT_CONFIG.dt then
        love.update = Hook.addbreakpoint(love.update, function(dt)
            return BALATRO_BOT_CONFIG.dt
        end)
    end

    -- Disable FPS cap
    if BALATRO_BOT_CONFIG.uncap_fps then
        G.FPS_CAP = 999999.0
    end

    -- Makes things move instantly instead of sliding
    if BALATRO_BOT_CONFIG.instant_move then
        function Moveable.move_xy(self, dt)
            -- Directly set the visible transform to the target transform
            self.VT.x = self.T.x
            self.VT.y = self.T.y
        end
    end

    -- Forcibly disable vsync
    if BALATRO_BOT_CONFIG.disable_vsync then
        love.window.setVSync(0)
    end

    -- Disable card scoring animation text
    if BALATRO_BOT_CONFIG.disable_card_eval_status_text then
        card_eval_status_text = function(card, eval_type, amt, percent, dir, extra) end
    end

    -- Only draw/present every Nth frame
    local original_draw = love.draw
    local draw_count = 0
    love.draw = function()
        draw_count = draw_count + 1
        if draw_count % BALATRO_BOT_CONFIG.frame_ratio == 0 then
            original_draw()
        end
    end

    local original_present = love.graphics.present
    love.graphics.present = function()
        if draw_count % BALATRO_BOT_CONFIG.frame_ratio == 0 then
            original_present()
        end
    end

    _RELEASE_MODE = false
    
    sendDebugMessage('init api')
    if Middleware.SETTINGS.api == true then
        -- local any_thing_could_do = {BalatrobotAPI.ACTIONS.SELL_CONSUMABLE, BalatrobotAPI.ACTIONS.SELL_JOKER, BalatrobotAPI.ACTIONS.REARRANGE_JOKERS}
        -- local shop_could_do = {BalatrobotAPI.ACTIONS.END_SHOP, 
        -- BalatrobotAPI.ACTIONS.REROLL_SHOP, 
        -- BalatrobotAPI.ACTIONS.BUY_BOOSTER, 
        -- BalatrobotAPI.ACTIONS.BUY_CARD, 
        -- BalatrobotAPI.ACTIONS.BUY_VOUCHER}
        -- Middleware.c_play_hand = Hook.addbreakpoint(Middleware.c_play_hand, function()
        --     BalatrobotAPI.waitingFor = 'select_cards_from_hand'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_discard_hand = Hook.addbreakpoint(Middleware.c_discard_hand, function()
        --     BalatrobotAPI.waitingFor = 'skip_or_select_blind'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_select_blind = Hook.addbreakpoint(Middleware.c_select_blind, function()
        --     BalatrobotAPI.waitingFor = 'select_booster_action'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_skip_blind = Hook.addbreakpoint(Middleware.c_skip_blind, function()
        --     BalatrobotAPI.waitingFor = 'select_shop_action'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_choose_booster_cards = Hook.addbreakpoint(Middleware.c_choose_booster_cards, function()
        --     BalatrobotAPI.waitingFor = 'rearrange_hand'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_skip_booster = Hook.addbreakpoint(Middleware.c_skip_booster, function()
        --     BalatrobotAPI.waitingFor = 'rearrange_consumables'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_buy_card = Hook.addbreakpoint(Middleware.c_buy_card, function()
        --     BalatrobotAPI.waitingFor = 'use_or_sell_consumables'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_buy_vouchers = Hook.addbreakpoint(Middleware.c_buy_vouchers, function()
        --     BalatrobotAPI.waitingFor = 'rearrange_jokers'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_buy_booster = Hook.addbreakpoint(Middleware.c_buy_booster, function()
        --     BalatrobotAPI.waitingFor = 'sell_jokers'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_reroll_shop = Hook.addbreakpoint(Middleware.c_reroll_shop, function()
        --     BalatrobotAPI.waitingFor = 'start_run'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_end_shop = Hook.addbreakpoint(Middleware.c_end_shop, function()
        --     BalatrobotAPI.waitingFor = 'start_run'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_use_consumable_card = Hook.addbreakpoint(Middleware.c_use_consumable_card, function()
        --     BalatrobotAPI.waitingFor = 'start_run'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_sell_consumable_card = Hook.addbreakpoint(Middleware.c_sell_consumable_card, function()
        --     BalatrobotAPI.waitingFor = 'start_run'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_sell_jokers = Hook.addbreakpoint(Middleware.c_sell_jokers, function()
        --     BalatrobotAPI.waitingFor = 'start_run'
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_cash_out = Hook.addbreakpoint(Middleware.c_cash_out, function()
        --     BalatrobotAPI.waitingFor = { unpack(shop_could_do), unpack(any_thing_could_do) }
        --     BalatrobotAPI.waitingForAction = true
        -- end)
        -- Middleware.c_start_run = Hook.addbreakpoint(Middleware.c_start_run, function()
        --     BalatrobotAPI.waitingFor = { BalatrobotAPI.ACTIONS.SELECT_BLIND, BalatrobotAPI.ACTIONS.SKIP_BLIND, unpack(any_thing_could_do) }
        --     BalatrobotAPI.waitingForAction = true
        -- end)
    end
end

return BalatrobotAPI