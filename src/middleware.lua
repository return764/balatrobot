Middleware = { }
Middleware.choosingboostercards = false

Middleware.queuedactions = List.new()
Middleware.currentaction = nil
Middleware.conditionalactions = { }

Middleware.BUTTONS = {

    -- Shop Phase Buttons
    END_SHOP = nil,
    REROLL = nil,

    -- Pack Phase Buttons
    SKIP_PACK = nil,

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

local function firewhenready(condition, func)
    for i = 1, #Middleware.conditionalactions do
        if Middleware.conditionalactions[i] == nil then
            Middleware.conditionalactions[i] = {
                ready = condition,
                fire = func
            }
            return nil
        end
    end

    Middleware.conditionalactions[#Middleware.conditionalactions + 1] = {
        ready = condition,
        fire = func
    }
end

local function queueaction(func, delay)

    if not delay then
        delay = Bot.SETTINGS.action_delay
    end

    List.pushleft(Middleware.queuedactions, { func = func, delay = delay })
end

local function pushbutton(button, delay)
    queueaction(function()
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

    -- Run functions that have been waiting for a condition to be met
    for i = 1, #Middleware.conditionalactions do
        if Middleware.conditionalactions[i] then
            local _result = {Middleware.conditionalactions[i].ready()}
            local _ready = table.remove(_result, 1)
            if _ready == true then
                Middleware.conditionalactions[i].fire(unpack(_result))
                Middleware.conditionalactions[i] = nil
            end
        end
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

function Middleware.c_shop()

    local _done_shopping = false

    local _b_round_end_shop = true
    local _b_reroll_shop = Middleware.BUTTONS.REROLL and Middleware.BUTTONS.REROLL.config and Middleware.BUTTONS.REROLL.config.button

    local _cards_to_buy = { }
    for i = 1, #G.shop_jokers.cards do
        _cards_to_buy[i] = G.shop_jokers.cards[i].cost <= G.GAME.dollars and G.shop_jokers.cards[i] or nil
    end

    local _vouchers_to_buy = { }
    for i = 1, #G.shop_vouchers.cards do
        _vouchers_to_buy[i] = G.shop_vouchers.cards[i].cost <= G.GAME.dollars and G.shop_vouchers.cards[i] or nil
    end

    local _boosters_to_buy = { }
    for i = 1, #G.shop_booster.cards do
        _boosters_to_buy[i] = G.shop_booster.cards[i].cost <= G.GAME.dollars and G.shop_booster.cards[i] or nil
    end

    local _choices = { }
    _choices[Bot.ACTIONS.END_SHOP] = _b_round_end_shop
    _choices[Bot.ACTIONS.REROLL_SHOP] = _b_reroll_shop
    _choices[Bot.ACTIONS.BUY_CARD] = #_cards_to_buy > 0 and _cards_to_buy or nil
    _choices[Bot.ACTIONS.BUY_VOUCHER] = #_vouchers_to_buy > 0 and _vouchers_to_buy or nil
    _choices[Bot.ACTIONS.BUY_BOOSTER] = #_boosters_to_buy > 0 and _boosters_to_buy or nil
    
    firewhenready(function()
        local _action, _card = Bot.select_shop_action(_choices)
        if _action then
            return true, _action, _card
        else
            return false
        end
    end,

    function(_action, _card)
        if _action == Bot.ACTIONS.END_SHOP then
            pushbutton(Middleware.BUTTONS.NEXT_ROUND)
            _done_shopping = true
        elseif _action == Bot.ACTIONS.REROLL_SHOP then
            pushbutton(Middleware.BUTTONS.REROLL)
        elseif _action == Bot.ACTIONS.BUY_CARD then
            clickcard(_choices[Bot.ACTIONS.BUY_CARD][_card[1]])
            usecard(_choices[Bot.ACTIONS.BUY_CARD][_card[1]])
        elseif _action == Bot.ACTIONS.BUY_VOUCHER then
            clickcard(_choices[Bot.ACTIONS.BUY_VOUCHER][_card[1]])
            usecard(_choices[Bot.ACTIONS.BUY_VOUCHER][_card[1]])
        elseif _action == Bot.ACTIONS.BUY_BOOSTER then
            _done_shopping = true
            clickcard(_choices[Bot.ACTIONS.BUY_BOOSTER][_card[1]])
            usecard(_choices[Bot.ACTIONS.BUY_BOOSTER][_card[1]])
        end
    
        if not _done_shopping then
            queueaction(function()
                firewhenready(function()
                    return G.shop ~= nil and G.STATE_COMPLETE and G.STATE == G.STATES.SHOP
                end, Middleware.c_shop)
            end)
        end
    end)
    
end

function Middleware.c_rearrange_hand()

    firewhenready(function()
        local _action, _order = Bot.rearrange_hand()
        if _action then
            return true, _action, _order
        else
            return false
        end
    end,

    function(_action, _order)
        Middleware.c_play_hand()

        if not _order or #_order ~= #G.hand.cards then return end

        queueaction(function()
            for k,v in ipairs(_order) do
                if k < v then
                    G.hand.cards[k], G.hand.cards[v] = G.hand.cards[v], G.hand.cards[k]
                end
            end

            G.hand:set_ranks()
        end)
    end)

end

function Middleware.c_rearrange_consumables()

    firewhenready(function()
        local _action, _order = Bot.rearrange_consumables()
        if _action then
            return true, _action, _order
        else
            return false
        end
    end,

    function(_action, _order)
        Middleware.c_rearrange_hand()

        if not _order or #_order ~= #G.consumables.cards  then return end

        queueaction(function()
            for k,v in ipairs(_order) do
                if k < v then
                    G.consumeables.cards[k], G.consumeables.cards[v] = G.consumeables.cards[v], G.consumeables.cards[k]
                end
            end

            G.consumeables:set_ranks()
        end)
    end)

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
    if _k == 'STATE' and _v == G.STATES.GAME_OVER then
        G.FUNCS.go_to_menu({})
    end

    if _k == 'STATE' and _v == G.STATES.MENU then
        Middleware.c_start_run()
    end
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
    -- G.CONTROLLER.snap_to = Hook.addcallback(G.CONTROLLER.snap_to, function(...)
    --     local _self = ...

    --     if _self and _self.snap_cursor_to.node and _self.snap_cursor_to.node.config and _self.snap_cursor_to.node.config.button then
            
    --         local _button = _self.snap_cursor_to.node
    --         local _buttonfunc = _self.snap_cursor_to.node.config.button

    --         if _buttonfunc == 'select_blind' and G.STATE == G.STATES.BLIND_SELECT then
    --             Middleware.c_select_blind()
    --         elseif _buttonfunc == 'cash_out' then
    --             pushbutton(_button)
    --         elseif _buttonfunc == 'toggle_shop' and G.shop ~= nil then -- 'next_round_button'
    --             Middleware.BUTTONS.NEXT_ROUND = _button

    --             firewhenready(function()
    --                 return G.shop ~= nil and G.STATE_COMPLETE and G.STATE == G.STATES.SHOP
    --             end, Middleware.c_shop)
    --         end
    --     end
    -- end)

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
    -- G = Hook.addonwrite(G, w_gamestate)
    G.update = Hook.addcallback(G.update, c_update)
end

return Middleware