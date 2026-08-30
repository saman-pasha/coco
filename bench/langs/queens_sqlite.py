"""The same 8-queens search, with the domain as DURABLE rows.

The honest sentence first: a backtracking search has almost no data,
so this lane is the same search in memory with the board's domain read
back from a committed table each rep -- which is also exactly what
cocolog's `--embed' does with it (the store attached, the thinking in
memory). A row that reads close to plain cpython here is the point,
not a flaw: it says durability costs a search nothing, on both sides.
"""
import sys, sqlite3

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

def main(n, reps, path):
    db = sqlite3.connect(path)
    db.execute("create table if not exists d (q integer primary key)")
    db.executemany("insert or replace into d values (?)",
                   [(q,) for q in range(1, n + 1)])
    db.commit()
    c = 0
    for _ in range(reps):
        un = [row[0] for row in db.execute("select q from d order by q")]
        out = [0]
        place(un, [], out)
        c = out[0]
    print("answer(%d)" % c)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
