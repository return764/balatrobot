from action import Actions
from langchain.prompts import PromptTemplate


ep1 = """
打出[D_2, D_3, D_4, D_5, D_6]
同花顺
"""

ep2 = """
打出[C_2, D_3, S_4, H_5, D_6]
顺子
"""

ep3 = """
打出[C_J, D_J, S_J]
三条
"""

ep4 = """
打出[C_2, D_2, S_2, H_2]
四条
"""

ep5 = """
打出[C_2, D_2, S_3, H_3]
两对
"""

ep6 = """
打出[C_2, C_7, C_J, C_K, C_A]
同花
"""

ep7 = """
打出[D_6, C_6]
打出[D_6, C_6, D_A, S_J]
对子
"""

ep8 = """
打出[D_5, C_6, S_J, H_K, D_A]
高牌, 只有D_A记分
打出[D_5, C_6, S_J, H_K]
高牌, 只有H_K记分
"""

action_examples_prompt = {
    Actions.SELECT_BLIND: """
        {{
            "action": 'SELECT_BLIND',
            "params": null,
            "reason": ""
        }}
    """,
    Actions.SKIP_BLIND: """
        {{
            "action": 'SKIP_BLIND',
            "params": null,
            "reason": ""
        }}
    """,
    Actions.PLAY_HAND: """
        {{
            "action": 'PLAY_HAND',
            "params": [1,2,3],
            "reason": "出这三张牌的原因是..."
        }}
        {{
            "action": 'PLAY_HAND',
            "params": [1,2,3,4,5],
            "reason": "出这五张牌的原因是..."
        }}
    """,
    Actions.DISCARD_HAND: """
        {{
            "action": 'DISCARD_HAND',
            "params": [1,2,3],
            "reason": "弃掉这三张牌的原因是..."
        }}
    """,
    Actions.END_SHOP: """
        {{
            "action": 'END_SHOP',
            "params": null,
            "reason": "离开商店的原因..."
        }}
    """,
    Actions.REROLL_SHOP: """
        {{
            "action": 'REROLL_SHOP',
            "params": null,
            "reason": "重掷商店卡牌的原因..."
        }}
    """,
    Actions.BUY_CARD: """
        {{
            "action": 'BUY_CARD',
            "params": [1],
            "reason": "买这个卡牌的原因..."
        }}
    """,
    Actions.BUY_VOUCHER: """
        {{
            "action": 'BUY_VOUCHER',
            "params": [1],
            "reason": "买这个优惠券的原因..."
        }}
    """,
    Actions.BUY_BOOSTER: """
        {{
            "action": 'BUY_BOOSTER',
            "params": 1,
            "reason": "买这个拓展包的原因..."
        }}
    """,
    Actions.SELECT_BOOSTER_CARD: """
        {{
            "action": 'SELECT_BOOSTER_CARD',
            "params": [1],
            "reason": "选择这个卡的原因..."
        }}
        {{
            "action": 'SELECT_BOOSTER_CARD',
            "params": [1, [1,2,3]],
            "reason": "对这三张牌使用这个卡的原因..."
        }}
    """,
    Actions.SKIP_BOOSTER_PACK: """
        {{
            "action": 'SKIP_BOOSTER_PACK',
            "params": null,
            "reason": "跳过补充包的原因是..."
        }}
    """,
    Actions.SELL_JOKER: """
        {{
            "action": 'SELL_JOKER',
            "params": [1],
            "reason": "卖掉这个小丑牌的原因是..."
        }}
    """,
    Actions.SELL_JOKER: """
        {{
            "action": 'SELL_JOKER',
            "params": [1],
            "reason": "卖掉这个小丑牌的原因是..."
        }}
    """,
    Actions.SELL_CONSUMABLE: """
        {{
            "action": 'SELL_CONSUMABLE',
            "params": [1],
            "reason": "卖掉这个消耗牌的原因是..."
        }}
    """,
    Actions.REARRANGE_JOKERS: """
        {{
            "action": 'REARRANGE_JOKERS',
            "params": [3, 1, 2],
            "reason": "调整小丑牌顺序的原因是..."
        }}
    """,
    Actions.CASH_OUT: """
        {{
            "action": 'CASH_OUT',
            "params": null,
            "reason": ""
        }}
    """
}

def get_current_action_example(actions):
    action_examples = []
    for action_str in actions:
        try:
            action_enum = getattr(Actions, action_str)
            if action_enum in action_examples_prompt:
                action_examples.append(action_examples_prompt[action_enum])
        except (AttributeError, KeyError) as e:
            print(f"Warning: Action {action_str} not found in examples: {e}")
            continue
            
    return "\n".join(action_examples) if action_examples else ""

play_hand_prompt = PromptTemplate.from_template(
    """
    当前手牌数:
    {hand_count}
    剩余出牌次数:
    {hands_left}
    剩余弃牌次数:
    {discards_left}
    当前得分:
    {chips}
    目标得分:
    {target_chips}
    当前手牌:
    {hand}
    """
)

shop_prompt = PromptTemplate.from_template(
    """
    商店信息:
    补充包:
    {boosters}
    优惠券:
    {vouchers}
    卡牌:
    {cards}
    当前存款:
    {dollars}
    重置商店的价格:
    {reroll_cost}
    """
)

error_prompt = PromptTemplate.from_template(
    """
    存在错误信息，考虑使用别的策略
    {error_message}
    """
)

data_schema = """
游戏状态schema如下:
$card:
    type: object
    properties:
        label:
            description: 卡牌名称
        card_key:
            description: 卡牌(H_A红桃A, S_1黑桃1, C_4梅花4, D_J方片J)
        edition:
            required: false
            description: holo: 加10倍率, foil: 加50筹码, polychrome: 倍率乘1.5倍, negative: 增加一个消耗槽位
        enhance:
            required: false
            description: m_gold: 黄金牌, m_bonus: 奖励牌, m_glass: 玻璃牌, m_lucky: 幸运牌, m_mult: 倍率牌, m_steel: 钢铁牌, m_stone: 石头牌, m_wild: 万能牌
        sell_cost:
            required: false
            description: 出售价格
        cost:
            required: false
            description: 购买价格

consumables: 
    type: array
    items:
        type: object
        reference: $card
deck:
    type: array
    description: 剩余牌组
    items:
        type: object
        reference: $card
hand:
    type: array
    description: 手牌，能打出的牌
    items:
        type: object
        reference: $card
shop:
    type: object
    properties:
        boosters:
            type: array
            items:
                type: object
                reference: $card
        vouchers:
            type: array
            items:
                type: object
                reference: $card
        cards:
            type: array
            items:
                type: object
                reference: $card
        reroll_cost:
            description: 重置商店价格
jokers:
    type: array
    items:
        type: object
        reference: $card
chips:
    description: 当前得分
state:
    description: 当前游戏状态
max_jokers:
    description: 最大小丑牌数量
dollars:
    description: 当前的存款
round:
    description: 当前回合数
current_round:
    type: object
    properties:
        hands_left:
            description: 当前回合剩余出牌次数
        discards_left:
            description: 当前回合剩余弃牌次数
tags:
    description: 本局游戏拥有的标签(暂不支持)
ante:
    type: object
    properties:
        blinds:
            type: object
            properties:
                chips:
                    description: 击败该盲注所需分数
                ondeck:
                    description: 盲注类型(Small, Big, Boss)
waitingForAction:
    description: 等待决策
waitingFor:
    description: 现在能做的决策类型
"""