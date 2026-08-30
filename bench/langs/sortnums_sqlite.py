"""The same generate-and-sort, with the DATABASE doing the sorting.

The generated numbers are committed as rows once -- the same LCG, the
same 5000 values -- and every rep asks the store for them in order:
`ORDER BY v' with no index on v, so SQLite sorts per rep the way
cocolog's lanes msort per rep. This is the one counterpart where the
work itself goes through the database rather than beside it, because
sorting IS a thing a store does.
"""
import sys, sqlite3

def main(n, reps, path):
    db = sqlite3.connect(path)
    db.execute("create table if not exists s (k integer primary key, v integer)")
    rows = []
    x = 12345
    for i in range(n):
        x = (1103515245 * x + 12345) % 2147483648
        rows.append((i, x % 100000))
    db.executemany("insert or replace into s values (?,?)", rows)
    db.commit()
    c = 0
    for _ in range(reps):
        a = 0
        for row in db.execute("select v from s order by v"):
            a = (a * 31 + row[0]) % 1000003
        c = a
    print("answer(%d)" % c)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
