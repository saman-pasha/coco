"""N queens, all solutions counted, Reps times -- the same backtracking."""
import sys

def safe(q, d, placed):
    for p in placed:
        if q == p + d or q == p - d:
            return False
        d += 1
    return True

def place(un, placed, out):
    if not un:
        out[0] += 1
        return
    for i, q in enumerate(un):
        if safe(q, 1, placed):
            place(un[:i] + un[i+1:], [q] + placed, out)

def main(n, reps):
    c = 0
    for _ in range(reps):
        out = [0]
        place(list(range(1, n + 1)), [], out)
        c = out[0]
    print("answer(%d)" % c)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]))
