#!/usr/bin/python3

import json
import socket
import threading
import time
import queue
from enum import Enum
import random

from ai import AiDecision, LLMExecutor

# 1 选牌 -> 2 记分 -> 3 发牌 -> 1 选牌
# 19 下一轮 -> 8 点击收钱 -> 5 进入商店
# 7 选择盲注 -> 1 选牌
# 2 记分不通过 -> 19下一回合 -> 4 游戏结束
class State(Enum):
    SELECTING_HAND = 1
    HAND_PLAYED = 2
    DRAW_TO_HAND = 3
    GAME_OVER = 4
    SHOP = 5
    PLAY_TAROT = 6
    BLIND_SELECT = 7
    ROUND_EVAL = 8
    TAROT_PACK = 9
    PLANET_PACK = 10
    MENU = 11
    TUTORIAL = 12
    SPLASH = 13
    SANDBOX = 14
    SPECTRAL_PACK = 15
    DEMO_CTA = 16
    STANDARD_PACK = 17
    BUFFOON_PACK = 18
    NEW_ROUND = 19


class Actions(Enum):
    GET_GAMESTATE = 0
    SELECT_BLIND = 1 #
    SKIP_BLIND = 2 #
    PLAY_HAND = 3 #
    DISCARD_HAND = 4 #
    END_SHOP = 5 #
    REROLL_SHOP = 6 #
    BUY_CARD = 7 #
    BUY_VOUCHER = 8 #?
    BUY_BOOSTER = 9 #?
    SELECT_BOOSTER_CARD = 10 #
    SKIP_BOOSTER_PACK = 11 #
    SELL_JOKER = 12 #
    USE_CONSUMABLE = 13 #
    SELL_CONSUMABLE = 14 #
    REARRANGE_JOKERS = 15 #
    REARRANGE_CONSUMABLES = 16 # no required
    REARRANGE_HAND = 17 # no required
    PASS = 18 # ?
    START_RUN = 19 # no required
    CASH_OUT = 20


class Bot:
    def __init__(
        self,
        deck: str,
        stake: int = 1,
        seed: str = None,
        challenge: str = None,
        bot_port: int = 12345
    ):
        self.G = None
        self.deck = deck
        self.stake = stake
        self.seed = seed
        self.challenge = challenge

        self.decision_event = threading.Event()
        self.game_state_queue = queue.Queue()

        self.bot_port = bot_port

        self.addr = ("localhost", self.bot_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.running = False
        self.llm_executor = LLMExecutor()

        self.state = {}
        self.last_state = None

    def sendcmd(self, cmd, **kwargs):
        msg = bytes(cmd, "utf-8")
        self.sock.sendto(msg, self.addr)

    def actionToCmd(self, action):
        result = []

        for x in action:
            if isinstance(x, Actions):
                result.append(x.name)
            elif type(x) is list:
                result.append(f"[{','.join([str(y) for y in x])}]")
            else:
                result.append(str(x))

        return "|".join(result)

    def random_seed(self):
        # e.g. 1OGB5WO
        return "".join(random.choices("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", k=7))

    def receive_thread(self):
        while self.running:
            try:
                print("receive_thread")
                data = self.sock.recv(65536)
                jsondata = json.loads(data)
                print(f"Received message: {jsondata}")
                
                # 如果需要决策,将游戏状态放入队列
                if jsondata.get("waitingForAction", True):
                    self.game_state_queue.put(jsondata)

            except Exception as e:
                print(f"Error in receive thread: {e}")
                self.running = False        

    def send_thread(self):
        self.send_action([Actions.GET_GAMESTATE])
        while self.running:
            try:
                # 从队列获取游戏状态
                game_state = self.game_state_queue.get()  # 使用阻塞的 get
                
                # 获取 AI 决策
                action = self.llm_executor.get_ai_decision(game_state)
                print(f"AI 决策: {action}")
                
                if action:
                    # 发送决策动作
                    self.send_action(action)
                    time.sleep(3)
                else:
                    print("AI 未能做出有效决策")
                    
            except Exception as e:
                print(f"Error in send thread: {e}")
                

    def send_action(self, action):
        cmdstr = self.actionToCmd(action)
        print(f"Sending message: {cmdstr}")
        self.sendcmd(cmdstr)

    def run(self):
        self.running = True
        receive_thread = threading.Thread(target=self.receive_thread)
        send_thread = threading.Thread(target=self.send_thread)

        receive_thread.start()
        send_thread.start()

        receive_thread.join()
        send_thread.join()

        self.sock.close()
        self.running = False
        
        # while self.running:
        #     try:
        #         # 接收游戏状态更新
        #         data = self.sock.recv(65536)
        #         jsondata = json.loads(data)
                
        #         if "state" in jsondata:
        #             # 状态已更新，可以发送新指令
        #             self.G = jsondata
                    
        #             # 检查状态是否改变
        #             if self.last_state != self.G["state"]:
        #                 self.last_state = self.G["state"]
        # cmdstr = self.actionToCmd([Actions.START_RUN, 1, "Plasma Deck", self.random_seed(), None])
        # cmdstr = self.actionToCmd([Actions.SKIP_BLIND])
        # cmdstr = self.actionToCmd([Actions.SELECT_BLIND])
        # cmdstr = self.actionToCmd([Actions.PLAY_HAND, [1,2,3]])
        # cmdstr = self.actionToCmd([Actions.DISCARD_HAND, [1,2,3]])
        # cmdstr = self.actionToCmd([Actions.BUY_CARD, [1,2]])
        #? cmdstr = self.actionToCmd([Actions.BUY_VOUCHER, [1]])
        # cmdstr = self.actionToCmd([Actions.BUY_BOOSTER, 1])
        # cmdstr = self.actionToCmd([Actions.SELECT_BOOSTER_CARD, [2], [2,3,4]]) # 使用第二张牌给2，3，4张手牌
        # cmdstr = self.actionToCmd([Actions.SKIP_BOOSTER_PACK])
        # cmdstr = self.actionToCmd([Actions.REROLL_SHOP])
        # cmdstr = self.actionToCmd([Actions.END_SHOP])
        # cmdstr = self.actionToCmd([Actions.USE_CONSUMABLE, [1], [2,3,5]])
        # cmdstr = self.actionToCmd([Actions.SELL_CONSUMABLE, [1]])
        # cmdstr = self.actionToCmd([Actions.SELL_JOKER, [1]])
                            
        #     except socket.timeout:
        #         # 超时继续等待
        #         continue
        #     except socket.error as e:
        #         print(f"Socket error: {e}")
        #         # 重新连接
        #         self.init_sock()
        #     except Exception as e:
        #         print(f"Error: {e}")
        #         self.running = False
        
