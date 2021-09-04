from collections import Counter
from brownie import ProvablyRareGem


def test_claim2(a):
    g = a[0].deploy(ProvablyRareGem)
    c = Counter()
    for i in range(200):
        vals = g.claim2(i)
        for v in vals:
            c[v] += 1
    for i in range(10):
        print(i, c[i])
    assert False


def test_uri(a):
    g = a[0].deploy(ProvablyRareGem)
    print(g.uri(5))
    assert False
