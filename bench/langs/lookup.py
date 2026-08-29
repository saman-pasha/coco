"""N facts, then sweeps of a thousand lookups -- a dict against a clause
database. The keys and the arithmetic are the Prolog side's, exactly."""
import sys

def main(n, reps):
    f = {}
    for k in range(n, 0, -1):
        f[k] = (k * 7) % 1000
    s = 0
    for _ in range(reps):
        a = 0
        m = 1000
        while m > 0:
            k = ((m * 37) % n) + 1
            v = f.get(k)
            if v is not None:
                a += v
            m -= 1
        s = a
    print("answer(%d)" % s)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]))
