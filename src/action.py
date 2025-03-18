from enum import Enum


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

    @staticmethod
    def from_value(value):
        """通过数字反查对应的Enum"""
        for action in Actions:
            if action.value == value:
                return action
        raise ValueError(f"没有对应的Action值: {value}")