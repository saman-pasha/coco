"""A counting loop: the sum of 1..N, one addition at a time, Reps times."""
import sys

def main(n, reps):
    s = 0
    for _ in range(reps):
        a = 0
        k = n
        while k > 0:
            a += k
            k -= 1
        s = a
    print("answer(%d)" % s)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]))
