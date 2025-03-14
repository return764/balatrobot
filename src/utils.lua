Utils = { }

function Utils.getCardData(card)
    local _card = { }

    _card.label = card.label
    _card.name = card.config.card.name
    _card.suit = card.config.card.suit
    _card.value = card.config.card.value
    _card.card_key = card.config.card_key

    return _card
end

function Utils.getDeckData()
    local _deck = { }

    if G and G.deck and G.deck.cards then
        for i = 1, #G.deck.cards do
            local _card = Utils.getCardData(G.deck.cards[i])
            _deck[i] = _card
        end
    end

    return _deck
end

function Utils.getHandData()
    local _hand = { }

    if G and G.hand and G.hand.cards then
        for i = 1, #G.hand.cards do
            local _card = Utils.getCardData(G.hand.cards[i])
            _hand[i] = _card
        end
    end

    return _hand
end

function Utils.getJokersData()
    local _jokers = { }

    if G and G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            local _card = Utils.getCardData(G.jokers.cards[i])
            _jokers[i] = _card
        end
    end

    return _jokers
end

function Utils.getConsumablesData()
    local _consumables = { }

    if G and G.consumeables and G.consumeables.cards then
        for i = 1, #G.consumeables.cards do
            local _card = Utils.getCardData(G.consumeables.cards[i])
            _consumables[i] = _card
        end
    end

    return _consumables
end

function Utils.getBlindData()
    local _blinds = { }

    if G and G.GAME then
        _blinds.ondeck = G.GAME.blind_on_deck
        _blinds.chips = G.GAME.blind and G.GAME.blind.chips
    end

    return _blinds
end

function Utils.getAnteData()
    local _ante = { }
    _ante.blinds = Utils.getBlindData()

    return _ante
end

function Utils.getBackData()
    local _back = { }

    return _back
end

function Utils.getShopData()
    local _shop = { }
    if not G or not G.shop then return _shop end
    
    _shop.reroll_cost = G.GAME.current_round.reroll_cost
    _shop.cards = { }
    _shop.boosters = { }
    _shop.vouchers = { }

    for i = 1, #G.shop_jokers.cards do
        _shop.cards[i] = Utils.getCardData(G.shop_jokers.cards[i])
    end

    for i = 1, #G.shop_booster.cards do
        _shop.boosters[i] = Utils.getCardData(G.shop_booster.cards[i])
    end

    for i = 1, #G.shop_vouchers.cards do
        _shop.vouchers[i] = Utils.getCardData(G.shop_vouchers.cards[i])
    end

    return _shop
end

function Utils.getHandScoreData()
    local _handscores = { }

    return _handscores
end

function Utils.getTagsData()
    local _tags = { }

    return _tags
end

function Utils.getRoundData()
    local _current_round = { }

    if G and G.GAME and G.GAME.current_round then
        _current_round.discards_left = G.GAME.current_round.discards_left
        _current_round.hands_left = G.GAME.current_round.hands_left
    end

    return _current_round
end

function Utils.getGameData()
    local _game = { }

    if G and G.STATE then
        _game.state = G.STATE
        _game.num_hands_played = G.GAME.hands_played -- 打出的手牌数
        _game.num_skips = G.GAME.skips -- 本轮跳过盲注的次数
        _game.round = G.GAME.round -- 游戏回合数
        _game.discount_percent = G.GAME.discount_percent -- 折扣比率
        _game.interest_cap = G.GAME.interest_cap -- 利息
        _game.inflation = G.GAME.inflation -- 通货膨胀， 购买后永久上涨
        _game.dollars = G.GAME.dollars
        _game.max_jokers = G.GAME.max_jokers
        _game.bankrupt_at = G.GAME.bankrupt_at -- 最小金额，信用卡会改变这个值
        _game.chips = G.GAME.chips -- 当前得分
    end

    return _game
end

function Utils.getGamestate()
    -- TODO
    local _gamestate = { }

    _gamestate = Utils.getGameData()
    
    _gamestate.deckback = Utils.getBackData()
    _gamestate.deck = Utils.getDeckData() -- Ensure this is not ordered
    _gamestate.hand = Utils.getHandData()
    _gamestate.jokers = Utils.getJokersData()
    _gamestate.consumables = Utils.getConsumablesData()
    _gamestate.ante = Utils.getAnteData()
    _gamestate.shop = Utils.getShopData() -- Empty if not in shop phase
    _gamestate.handscores = Utils.getHandScoreData()
    _gamestate.tags = Utils.getTagsData()
    _gamestate.current_round = Utils.getRoundData()

    return _gamestate
end

function printTable(tbl, level, indent)
    level = level or 0
    indent = indent or 0

    -- 生成缩进字符串
    local indentStr = string.rep("  ", indent)

    -- 遍历表格
    for key, value in pairs(tbl) do
        -- 打印键
        io.write(indentStr .. tostring(key) .. ": ")

        -- 根据值的类型进行处理
        if type(value) == "table" then
            -- 如果值是表格，递归打印
            io.write("\n")
            printTable(value, level + 1, indent + 1)
        else
            -- 如果值不是表格，直接打印
            io.write(tostring(value) .. "\n")
        end
    end
end

function splitString(input, delimiter)
    local result = {}
    local start = 1
    local pos = 1

    while true do
        pos = string.find(input, delimiter, start, true)  -- 使用 true 来进行字面匹配
        if pos then
            table.insert(result, string.sub(input, start, pos - 1))
            start = pos + 1
        else
            table.insert(result, string.sub(input, start))
            break
        end
    end

    return result
end

function Utils.parseaction(data)
    -- Protocol is ACTION|arg1|arg2
    local action = data:match("^([%a%u_]*)")
    local params = data:match("|(.*)")

    if action then
        local _action = BalatrobotAPI.ACTIONS[action]
        if not _action then
            return nil
        end

        local _actiontable = { }
        _actiontable[1] = _action

        if params then
            -- 首先按 | 分割参数
            local _args = splitString(params, "|")
            for i, arg in ipairs(_args) do
                if arg ~= '' then
                    if arg:match("^(%b[])") then
                        arg = arg:sub(2, -2)
                        local _splitparams = splitString(arg, ",")
                        local _paramtable = {}
                        for j, param in ipairs(_splitparams) do
                            if param ~= '' then
                                if param == 'None' then
                                    _paramtable[j] = false
                                else
                                    _paramtable[j] = tonumber(param) or param
                                end
                            end
                        end
                        _actiontable[i + 1] = _paramtable
                    else
                        -- 单个参数直接转换
                        if arg == 'None' then
                            _actiontable[i + 1] = false
                        else
                            _actiontable[i + 1] = tonumber(arg) or arg
                        end
                    end
                end
            end
        end
        printTable(_actiontable)
        return _actiontable
    end
end

Utils.ERROR = {
    NOERROR = 1,
    NUMPARAMS = 2,
    MSGFORMAT = 3,
    INVALIDACTION = 4,
}

function Utils.validateAction(action)
    if not action[1] or not BalatrobotAPI.ACTIONPARAMS[action[1]] then
        return Utils.ERROR.INVALIDACTION
    end

    local actionCell = BalatrobotAPI.ACTIONPARAMS[action[1]]
    
    local params = {unpack(action, 2)}
    if #params ~= actionCell.num_args then
        return Utils.ERROR.NUMPARAMS
    end
    
    if not actionCell.isvalid(params) then
        return Utils.ERROR.INVALIDACTION
    end
    
    return nil
end

function Utils.isTableUnique(table)
    if table == nil then return true end

    local _seen = { }
    for i = 1, #table do
        if _seen[table[i]] then return false end
        _seen[table[i]] = table[i]
    end

    return true
end

function Utils.isTableInRange(table, min, max)
    if table == nil then return true end

    for i = 1, #table do
        if table[i] < min or table[i] > max then return false end
    end
    return true
end

return Utils