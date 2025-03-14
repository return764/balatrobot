Middleware = { }

Middleware.queuedactions = List.new()
Middleware.currentaction = nil

Middleware.BUTTONS = {

    CASH_OUT = nil,
    -- Shop Phase Buttons
    END_SHOP = nil,
    REROLL = nil,

    -- Pack Phase Buttons
    SKIP_PACK = nil,

}

Middleware.SETTINGS = {
    stake = 1,
    deck = "Plasma Deck",

    -- Keep these nil for random seed
    seed = nil,
    challenge = '',

    -- Time between actions the bot takes (pushing buttons, clicking cards, etc.)
    -- Minimum is 1 frame per action
    action_delay = 0,

    -- Receive commands from the API?
    api = true,
}

function random_key(tb)
    local keys = {}
    for k in pairs(tb) do table.insert(keys, k) end
    return keys[math.random(#keys)]
end

function random_element(tb)
    local keys = {}
    for k in pairs(tb) do table.insert(keys, k) end
    return tb[keys[math.random(#keys)]]
end

function Middleware.add_event_sequence(events)

    local _lastevent = nil
    local _totaldelay = 0.0

    for k, event in pairs(events) do
        _totaldelay = _totaldelay + event.delay

        local _event = Event({
            trigger = 'after',
            delay = _totaldelay,
            blocking = false,
            func = function()
                event.func(event.args)
                return true
            end
        })
        G.E_MANAGER:add_event(_event)
        _lastevent = _event
    end

    return _lastevent
end

local function queueaction(func, delay)

    if not delay then
        delay = Middleware.SETTINGS.action_delay
    end

    List.pushleft(Middleware.queuedactions, { func = func, delay = delay })
end

local function pushbutton(button, delay)
    queueaction(function()
        print('button: '..tostring(button))
        if button and button.config and button.config.button then
            G.FUNCS[button.config.button](button)
        end
    end, delay)
end

local function pushbutton_instant(button, delay)
    if button and button.config and button.config.button then
        G.FUNCS[button.config.button](button)
    end
end

local function clickcard(card, delay)
    queueaction(function()
        --if card and card.click then
            card:click()
        --end
    end, delay)
end

local function usecard(card, sell, delay)

    queueaction(function()
        local _use_button = nil
        local _use_button = card.children.use_button and card.children.use_button.definition
        if _use_button and _use_button.config.button == nil then
            if card.ability.set == 'Joker' then
                -- 出售小丑牌
                local _sell_button = _use_button.nodes[1].nodes[1].nodes[1].nodes[1]
                pushbutton_instant(_sell_button, delay)
            elseif card.ability.consumeable then
                if sell then
                    -- 出售消耗卡
                    local _sell_button = _use_button.nodes[1].nodes[1].nodes[1].nodes[1]
                    pushbutton_instant(_sell_button, delay)
                else
                    -- 使用消耗卡
                    local _use_button = _use_button.nodes[1].nodes[2].nodes[1].nodes[1]
                    pushbutton_instant(_use_button, delay)
                end
            end
            return
        end

        
        local _buy_and_use_button = card.children.buy_and_use_button and card.children.buy_and_use_button.definition
        local _buy_button = card.children.buy_button and card.children.buy_button.definition

        if _buy_and_use_button then
            pushbutton_instant(_buy_and_use_button, delay)
        elseif _buy_button then
            pushbutton_instant(_buy_button, delay)
        end
    end, delay)
end

local function c_update()

    -- Process the queue of Bot events, max 1 per frame
    _events = { }
    if not List.isempty(Middleware.queuedactions) and
        (not Middleware.currentaction or 
            (Middleware.currentaction and Middleware.currentaction.complete)) then

        local _func_and_delay = List.popright(Middleware.queuedactions)
        Middleware.currentaction = Middleware.add_event_sequence({{ func = _func_and_delay.func, delay = _func_and_delay.delay }})
    end

end



function Middleware.c_play_hand(cards)
    for i = 1, #cards do
        clickcard(G.hand.cards[cards[i]])
    end

    pushbutton(UIBox:get_UIE_by_ID('play_button', G.buttons.UIRoot))
end

function Middleware.c_discard_hand(cards)
    for i = 1, #cards do
        clickcard(G.hand.cards[cards[i]])
    end

    pushbutton(UIBox:get_UIE_by_ID('discard_button', G.buttons.UIRoot))
end

function Middleware.c_select_blind()
    local _select_button = G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID('select_blind_button')
    pushbutton(_select_button)
end

function Middleware.c_skip_blind()
    local _skip_button = G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID('tag_'..G.GAME.blind_on_deck).children[2]
    pushbutton(_skip_button)
end

function Middleware.c_choose_booster_cards(booster_card_indexes, hand_card_indexes)
    for i = 1, #hand_card_indexes do
        clickcard(G.hand.cards[hand_card_indexes[i]])
    end

    for i = 1, #booster_card_indexes do
        clickcard(G.pack_cards.cards[booster_card_indexes[1]])
        usecard(G.pack_cards.cards[booster_card_indexes[1]])
    end
end

function Middleware.c_skip_booster()
    pushbutton(Middleware.BUTTONS.SKIP_PACK)
end

function Middleware.c_buy_card(cards)
    if not cards then return end

    for i = 1, #cards do
        clickcard(G.shop_jokers.cards[cards[i]])
        usecard(G.shop_jokers.cards[cards[i]])
    end
end

function Middleware.c_buy_vouchers(cards)
    if not cards then return end

    for i = 1, #cards do
        clickcard(G.shop_vouchers.cards[cards[i]])
        usecard(G.shop_vouchers.cards[cards[i]])
    end
end

function Middleware.c_buy_booster(index)
    clickcard(G.shop_booster.cards[index])
    usecard(G.shop_booster.cards[index])
end

function Middleware.c_reroll_shop()
    pushbutton(Middleware.BUTTONS.REROLL)
end

function Middleware.c_end_shop()
    pushbutton(G.shop:get_UIE_by_ID('next_round_button'))
end

function Middleware.c_use_consumable_card(consumable_card_indexes, hand_card_indexes)
    for i = 1, #hand_card_indexes do
        clickcard(G.hand.cards[hand_card_indexes[i]])
    end

    for i = 1, #consumable_card_indexes do
        clickcard(G.consumeables.cards[consumable_card_indexes[1]])
        usecard(G.consumeables.cards[consumable_card_indexes[1]])
    end
end

function Middleware.c_sell_consumable_card(card_indexes)
    for i = 1, #card_indexes do
        clickcard(G.consumeables.cards[card_indexes[1]])
        usecard(G.consumeables.cards[card_indexes[1]], true)
    end
end


function Middleware.c_rearrange_jokers(order)
    queueaction(function()
        for k, v in ipairs(order) do
            if k < v then
                G.jokers.cards[k], G.jokers.cards[v] = G.jokers.cards[v], G.jokers.cards[k]
            end
        end

        G.jokers:set_ranks()
    end)

end

function Middleware.c_sell_jokers(cards)
    if cards then
        for i = 1, #cards do
            clickcard(G.jokers.cards[cards[i]])
            usecard(G.jokers.cards[cards[i]])
        end
    end
end

function print_UIBox_structure(ui_box, depth, max_depth)
    -- 初始化参数
    depth = depth or 0
    max_depth = max_depth or 10  -- 防止无限递归
    
    if depth > max_depth then return end
    
    -- 创建缩进
    local indent = string.rep("  ", depth)
    
    -- 如果ui_box为空则返回
    if not ui_box then 
        print(indent.."nil UIBox")
        return 
    end
    
    -- 打印基本信息
    print(indent.."UIBox {")
    
    -- 打印Transform信息
    if ui_box.T then
        print(indent.."  Transform: {")
        print(indent.."    x: "..tostring(ui_box.T.x))
        print(indent.."    y: "..tostring(ui_box.T.y))
        print(indent.."    w: "..tostring(ui_box.T.w))
        print(indent.."    h: "..tostring(ui_box.T.h))
        print(indent.."  }")
    end
    
    -- 打印配置信息
    if ui_box.config then
        print(indent.."  Config: {")
        print(indent.."    id: "..tostring(ui_box.config.id))
        print(indent.."    button: "..tostring(ui_box.config.button))
        -- 其他配置信息...
        print(indent.."  }")
    end
    
    -- 递归打印children
    if ui_box.children then
        print(indent.."  Children: {")
        for k, child in pairs(ui_box.children) do
            print(indent.."    ["..tostring(k).."] =>")
            print_UIBox_structure(child, depth + 2, max_depth)
        end
        print(indent.."  }")
    end
    
    print(indent.."}")
end

function Middleware.c_cash_out()
    pushbutton(Middleware.BUTTONS.CASH_OUT)
end

function Middleware.c_start_run(stake, deck, seed, challenge)
    challenge = challenge or nil
    queueaction(function()
        -- for k, v in pairs(G.P_CENTER_POOLS.Back) do
        --     if v.name == deck then
        --         G.GAME.selected_back:change_to(v)
        --         G.GAME.viewed_back:change_to(v)
        --     end
        -- end

        -- for i = 1, #G.CHALLENGES do
        --     if G.CHALLENGES[i].name == challenge then
        --         challenge = G.CHALLENGES[i]
        --     end                    
        -- end
        G.FUNCS.start_run(nil, {stake = stake, seed = seed, challenge = challenge})
        end, 1.0)
end


local function w_gamestate(...)
    local _t, _k, _v = ...

    -- If we lose a run, we want to go back to the main menu
    -- Before we try to start a new run
    -- if _k == 'STATE' and _v == G.STATES.GAME_OVER then
    --     G.FUNCS.go_to_menu({})
    -- end

    -- if _k ~= 'PREV_GARB' 
    -- and _k ~= 'FPS_CAP' 
    -- and _k ~= 'SPEEDFACTOR' 
    -- and _k ~= 'JIGGLE_VIBRATION' 
    -- and _k ~= 'CURR_VIBRATION' 
    -- and _k ~= 'DRAW_HASH' 
    -- and _k ~= 'real_dt' 
    -- and _k ~= 'shared_shadow' 
    -- and _k ~= 'under_overlay' 
    -- and _k ~= 'MAJORS' 
    -- and _k ~= 'MINORS' 
    -- and _k ~= 'VIBRATION' 
    -- and _k ~= 'ALERT_ON_SCREEN' 
    -- and _k ~= 'screenwipe_amt' 
    -- and _k ~= 'ACC_state' 
    -- and _k ~= 'PITCH_MOD' 
    -- and _k ~= 'SPLASH_VOL' 
    -- and _k ~= 'boss_throw_hand' 
    -- and _k ~= 'ACC' 
    -- and _k ~= 'ACHIEVEMENTS' 
    -- and _k ~= 'ID' 
    -- and _k ~= 'E_SWITCH_POINT' 
    -- and _k ~= 'REFRESH_FRAME_MAJOR_CACHE' 
    -- and _k ~= 'new_frame' then
    --     print('k: '..tostring(_k))
    --     print('v: '..tostring(_v))
    -- end

    if _k == 'STATE' then
        if G.hand and G.hand.cards then
            print('hand card#'..tostring(#G.hand.cards))
            print('G.hand.config.card_limit <= 0'..tostring(G.hand.config.card_limit <= 0))
        end
        local any_thing_could_do = {BalatrobotAPI.ACTIONS.SELL_CONSUMABLE, BalatrobotAPI.ACTIONS.SELL_JOKER, BalatrobotAPI.ACTIONS.REARRANGE_JOKERS}

        if _v == G.STATES.MENU then
            BalatrobotAPI.waitingFor = {BalatrobotAPI.ACTIONS.START_RUN}
            BalatrobotAPI.waitingForAction = true
        end

        if _v == G.STATES.SELECTING_HAND then
            BalatrobotAPI.waitingFor = {BalatrobotAPI.ACTIONS.PLAY_HAND,  BalatrobotAPI.ACTIONS.DISCARD_HAND, unpack(any_thing_could_do)}
            BalatrobotAPI.waitingForAction = true
        end

        if _v == G.STATES.NEW_ROUND then
            BalatrobotAPI.waitingFor = {BalatrobotAPI.ACTIONS.CASH_OUT}
            BalatrobotAPI.waitingForAction = true
        end

        if _v == G.STATES.SHOP then
            BalatrobotAPI.waitingFor = {
                BalatrobotAPI.ACTIONS.END_SHOP, 
                BalatrobotAPI.ACTIONS.REROLL_SHOP, 
                BalatrobotAPI.ACTIONS.BUY_BOOSTER, 
                BalatrobotAPI.ACTIONS.BUY_CARD, 
                BalatrobotAPI.ACTIONS.BUY_VOUCHER, 
                unpack(any_thing_could_do)
            }
            BalatrobotAPI.waitingForAction = true
        end

        if _v == G.STATES.SMODS_BOOSTER_OPENED then
            BalatrobotAPI.waitingFor = {
                BalatrobotAPI.ACTIONS.SELECT_BOOSTER_CARD,
                BalatrobotAPI.ACTIONS.USE_CONSUMABLE,
                unpack(any_thing_could_do)
            }
            BalatrobotAPI.waitingForAction = true
        end
    end
    return _k, _v
end

local function c_initgamehooks()

    -- Hooks break SAVE_MANAGER.channel:push so disable saving. Who needs it when you are botting anyway...
    -- G.SAVE_MANAGER = {
    --     channel = {
    --         push = function() end
    --     }
    -- }

    -- Detect when hand has been drawn
    -- G.GAME.blind.drawn_to_hand = Hook.addcallback(G.GAME.blind.drawn_to_hand, function(...)
    --     firewhenready(function()
    --         return G.buttons and G.STATE_COMPLETE and G.STATE == G.STATES.SELECTING_HAND
    --     end, function()
    --         Middleware.c_sell_jokers()
    --     end)
    -- end)

    -- Hook button snaps
    G.CONTROLLER.snap_to = Hook.addcallback(G.CONTROLLER.snap_to, function(...)
        local _self = ...

        if _self and _self.snap_cursor_to.node and _self.snap_cursor_to.node.config and _self.snap_cursor_to.node.config.button then
            
            local _button = _self.snap_cursor_to.node
            local _buttonfunc = _self.snap_cursor_to.node.config.button

            if _buttonfunc == 'cash_out' then
                Middleware.BUTTONS.CASH_OUT = _button
            end
        end
    end)

    -- Toggle shop
    -- G.FUNCS.toggle_shop = Hook.addcallback(G.FUNCS.toggle_shop, function(...)
    --     local _e = ...
    --     print(e.config.id)
    --     Middleware.BUTTONS.END_SHOP = _e
    -- end)

    -- Set reroll availability
    G.FUNCS.can_reroll = Hook.addcallback(G.FUNCS.can_reroll, function(...)
        local _e = ...
        Middleware.BUTTONS.REROLL = _e
    end)

    -- Booster pack skip availability
    G.FUNCS.can_skip_booster = Hook.addcallback(G.FUNCS.can_skip_booster, function(...)
        local _e = ...
        Middleware.BUTTONS.SKIP_PACK = _e
    end)
end

function Middleware.hookbalatro()
    -- Unlock all card backs
    -- for k, v in pairs(G.P_CENTERS) do
    --     if not v.demo and not v.wip and v.set == "Back" then 
    --         v.alerted = true
    --         v.discovered = true
    --         v.unlocked = true
    --     end
    -- end

    -- Start game from main menu
    G.start_run = Hook.addcallback(G.start_run, c_initgamehooks)
    G.update = Hook.addcallback(G.update, c_update)
    -- G = Hook.addonwrite(G, w_gamestate) -- bug found
end

return Middleware