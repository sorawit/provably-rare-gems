from brownie import a, ProvablyRareGem


def main():
    g = ProvablyRareGem.deploy({'from': a[0]})
    x = a.at('0x052564eb0fd8b340803df55def89c25c432f43f4', force=True)
    tx = g.claim(404, {'from': x})
    print(tx)
    tx = g.claim(404, {'from': x})
    print(tx)
