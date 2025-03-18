#!/usr/bin/python3

from bot import Bot


if __name__ == "__main__":
    mybot = Bot(deck="Plasma Deck", stake=1, seed="1OGB5WO")

    mybot.run()
