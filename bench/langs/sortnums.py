"""Sort N pseudo-random integers, Reps times -- the same recurrence."""
import sys

def main(n, reps):
    c = 0
    for _ in range(reps):
        l = []
        x = 12345
        for _i in range(n):
            x = (1103515245 * x + 12345) % 2147483648
            l.append(x % 100000)
        a = 0
        for h in sorted(l):
            a = (a * 31 + h) % 1000003
        c = a
    print("answer(%d)" % c)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]))
