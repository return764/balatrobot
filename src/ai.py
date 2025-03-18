import json
from langchain.prompts import PromptTemplate
from langchain_openai import ChatOpenAI
from langchain_core.output_parsers import JsonOutputParser
from pydantic import BaseModel, Field

from bot import Actions
from config import AI_CONFIG


class AiDecision(BaseModel):
    action: str = Field(description="action to take")
    params: list = Field(description="parameters for the action")
    reason: str = Field(description="reason for the action")


class LLMExecutor:
    def __init__(self):
        self.llm = ChatOpenAI(
            base_url=AI_CONFIG["base_url"],
            api_key=AI_CONFIG["api_key"],
            model=AI_CONFIG["model"],
        )
        self.decision_prompt = PromptTemplate.from_template(
            """
            你是一名小丑牌（Balatro）游戏大师，目标是在有限的回合内，通过打出手牌组成不同牌型来击败盲注并完成关卡。以下是游戏的基本规则和流程：

            ---

            ### 游戏目标
            - 在有限的出牌次数内，得分超过当前盲注的分数，即可过关。

            ---

            ### 游戏基本元素
            - **盲注**：每一关卡有3个盲注，分别是：
            - 小盲注（Small Blind）
            - 大盲注（Big Blind）
            - Boss盲注（Boss Blind）
            - **商店**：击败盲注后，玩家可以进入商店购买功能牌。
            - **牌型**：通过打出手牌组成以下牌型来计算得分：
            - 同花顺（Royal Flush）
                五张牌点数连续且花色相同
            - 四条（Four of a Kind）
                四个一样点数的牌
            - 葫芦（Full House）
                三个一样点数的牌和两个一样点数的牌
            - 同花（Flush）
                五张花色相同的牌
            - 顺子（Straight）
                五张牌点数连续
            - 三条（Three of a Kind）
                三个一样点数的牌
            - 两对（Two Pair）
                两对一样点数的牌
            - 对子（Pair）
                两个一样点数的牌
            - 高牌（High Card）
                打出的牌中点数最高的一张牌
            ---

            ### 牌的表示
            - **花色**：
            - C（Club）：梅花
            - D（Diamond）：方块
            - S（Spade）：黑桃
            - H（Heart）：红桃
            - **牌面**：牌面用数字或字母表示，例如：
            - H_A：红桃A
            - S_1：黑桃1
            - C_4：梅花4
            - D_J：方块J

            ---

            ### 牌的特殊属性
            - **版本（Edition）**：
            - holo：倍率加10倍
            - foil：筹码加50
            - polychrome：倍率乘1.5倍
            - negative：增加一个槽位
            - **增强（Enhance）**：
            - m_gold：黄金牌，回合结束时，如果在手牌中，则+3存款
            - m_bonus：奖励牌，记分时获得30筹码
            - m_glass：玻璃牌，记分时乘2倍率，1/3的概率摧毁该卡牌
            - m_lucky：幸运牌，记分时1/5的概率+20倍率，1/15的概率获得20存款
            - m_mult：倍率牌，记分时加4倍率
            - m_steel：钢铁牌，记分时倍率乘1.5倍
            - m_stone：石头牌，记分时加50筹码
            - m_wild：万能牌，作为任意花色

            ---

            ### 游戏流程
            1. **初始状态**：
            - 玩家获得初始牌组（deck）和手牌（hand）。
            - 游戏状态包括当前回合数（round）、当前得分（chips）、存款（dollars）等。
            2. **回合开始**：
            - 玩家需要根据当前游戏状态（game_state）和可用动作（available_actions）选择行动。
            - 每个回合有有限的出牌次数（hands_left）和弃牌次数（discards_left）。
            3. **行动选择**：
            - **选择盲注(SELECT_BLIND)**:玩家可以选择挑战小盲注、大盲注或Boss盲注。
            - **打出牌（PLAY_HAND）**：玩家从手牌中打出牌，组成牌型。
            - **使用消耗品（USE_CONSUMABLE）**：玩家可以使用商店购买的消耗品。
            4. **得分计算**：
            - 得分 = 筹码 乘 倍率。
            - 筹码得分由打出的牌的点数相加得到，倍率由牌型决定。
            5. **商店互动**：
            - 玩家可以在商店购买功能牌或重置商店（reroll）。
            - 商店包含以下类型的牌：
                - 补充包（boosters）
                - 优惠券（vouchers）
                - 小丑牌，消耗牌，游戏牌，塔罗牌，星球牌（cards）
            

            ---

            ### 游戏结束条件
            - 玩家在有限的出牌次数内，得分超过当前盲注的分数，即可进入下一回合。通过第8回合时，游戏通关。
            - 如果玩家未能在规定次数内击败盲注，则游戏失败。

            当前游戏状态:
            {game_state}

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
            可用动作:
            {available_actions}

            请选择一个动作并给出具体参数, params的index以1开始。按json格式返回, 只返回json, 例如:
            eg1:
            {{
                "action": 'SELECT_BLIND',
                "params": null,
                "reason": ""
            }}
            eg2:
            {{
                "action": 'PLAY_HAND',
                "params": [1,2,3],
                "reason": "出这三张牌的原因是..."
            }}
            eg3:
            {{
                "action": 'USE_CONSUMABLE',
                "params": ["Mercury", [1,2,3]],
                "reason": "使用这张消耗牌的原因是..."
            }}
            """
        )

    def get_ai_decision(self, game_state):
        """使用 LLM 获取决策"""
        try:
            parser = JsonOutputParser(pydantic_object=AiDecision)
            # 调用 LLM 获取决策
            llm_chain = self.decision_prompt | self.llm | parser
            # 准备输入参数
            prompt_input = {
                "game_state": game_state,
                "available_actions": game_state.get("waitingFor", [])
            }
            
            # 获取 LLM 响应
            response = llm_chain.invoke(prompt_input)

            # 解析响应获取 action 和 params
            try:
                action = getattr(Actions, response["action"])
                params = response["params"]
                if params is None:
                    return [action]
                return [action, params]
                    
                    
            except json.JSONDecodeError:
                print("LLM响应格式错误")
                return None
            except (KeyError, AttributeError) as e:
                print(f"解析LLM响应出错: {e}")
                return None
                
        except Exception as e:
            print(f"AI决策出错: {e}")
            return None