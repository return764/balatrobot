from bot import Bot, Actions

def select_shop_action(self, G):
    if "num_shops" not in self.state:
        self.state["num_shops"] = 0

    self.state["num_shops"] += 1

    if self.state["num_shops"] == 1:
        return [Actions.BUY_CARD, [2]]
    elif self.state["num_shops"] == 5:
        return [Actions.BUY_CARD, [2]]

    return [Actions.END_SHOP]


def select_booster_action(self, G):
    return [Actions.SKIP_BOOSTER_PACK]


def sell_jokers(self, G):
    if len(G["jokers"]) > 1:
        return [Actions.SELL_JOKER, [2]]

    return [Actions.SELL_JOKER, []]


def rearrange_jokers(self, G):
    return [Actions.REARRANGE_JOKERS, []]


def use_or_sell_consumables(self, G):
    return [Actions.USE_CONSUMABLE, []]


def rearrange_consumables(self, G):
    return [Actions.REARRANGE_CONSUMABLES, []]


def rearrange_hand(self, G):
    return [Actions.REARRANGE_HAND, []]


if __name__ == "__main__":
    mybot = Bot(deck="Plasma Deck", stake=1, seed="1OGB5WO")

    mybot.run()
