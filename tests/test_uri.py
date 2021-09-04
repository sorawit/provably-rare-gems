from brownie import ProvablyRareGem


def test_uri(a):
    g = a[0].deploy(ProvablyRareGem)
    print(g.uri(5))
    assert False
