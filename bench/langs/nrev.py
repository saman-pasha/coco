"""naive reverse -- the same algorithm, cell for cell.

`app` is the quadratic append Prolog's nrev is built from; keeping it
means both sides do the same work rather than the same errand.
"""
import sys

def app(a, b):
    r = list(b)
    for x in reversed(a):
        r.insert(0, x)
    return r

def nrev(l):
    if not l:
        return []
    return app(nrev(l[1:]), [l[0]])

def sum31(l):
    a = 0
    for h in l:
        a = (a * 31 + h) % 1000003
    return a

def main(n, reps):
    l = list(range(1, n + 1))
    c = 0
    for _ in range(reps):
        c = sum31(nrev(l))
    print("answer(%d)" % c)

if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main(int(sys.argv[1]), int(sys.argv[2]))
