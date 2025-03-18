import json
from langchain.prompts import PromptTemplate
from langchain_openai import ChatOpenAI
from langchain_core.output_parsers import JsonOutputParser
from pydantic import BaseModel, Field

from action import Actions
from config import AI_CONFIG
from prompt import get_current_action_example, play_hand_prompt, shop_prompt, error_prompt

class AiDecision(BaseModel):
    action: str = Field(description="action to take")
    params: list = Field(description="parameters for the action")
    reason: str = Field(description="reason for the action")


class LLMExecutor:
    def __init__(self):
        self.latest_game_state = None
        self.llm = ChatOpenAI(
            base_url=AI_CONFIG["base_url"],
            api_key=AI_CONFIG["api_key"],
            model=AI_CONFIG["model"],
        ).with_structured_output(None, method="json_mode")
        
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

            ---
            {game_step_prompt}

            可用动作:
            {available_actions}

            请选择一个动作并给出具体参数, params的index以1开始。 例如:
            {action_examples}
            --- 
            {error_prompt}

            ---
            使用json格式返回
            """
        )

    def get_ai_decision(self, game_state):
        """使用 LLM 获取决策"""
        try:
            error = game_state.get("error")
            error_action = game_state.get("action")
            # 调用 LLM 获取决策
            llm_chain = self.decision_prompt | self.llm
            
            # 检查是否有错误
            if not error:
                self.latest_game_state = game_state
            else:
                game_state = self.latest_game_state

            waiting_for_aciton = game_state.get("waitingFor", [])

            if error_action is not None:
                waiting_for_aciton.remove(Actions.from_value(error_action).name)

            state = game_state.get("state", 999)

            game_step_prompt = None
            if state == 1:
                game_step_prompt = play_hand_prompt.invoke({
                "hand_count": len(game_state.get("hand", [])),
                "hands_left": game_state.get("current_round").get("hands_left", 0),
                "discards_left": game_state.get("current_round").get("discards_left", 0),
                "chips": game_state.get("chips", 0),
                "target_chips": game_state.get("ante").get("blinds").get("chips", 0),
                "hand": game_state.get("hand", [])
            })
            elif state == 5:
                game_step_prompt = shop_prompt.invoke({
                "boosters": game_state.get("shop").get("boosters", []),
                "vouchers": game_state.get("shop").get("vouchers", []),
                "cards": game_state.get("shop").get("cards", []),
                "dollars": game_state.get("dollars", 0),
                "reroll_cost": game_state.get("shop").get("reroll_cost", 0)
            })

            # 获取 LLM 响应
            response = llm_chain.invoke({
                "game_step_prompt": game_step_prompt if game_step_prompt else "",
                "available_actions": waiting_for_aciton,
                "action_examples": get_current_action_example(waiting_for_aciton),
                "error_prompt": error_prompt.invoke({
                    "error_message": error
                }) if error else None
            })

            print(f"LLM 响应: {response}")
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