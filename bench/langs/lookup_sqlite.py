"""The same lookups, against a DURABLE, transactional store.

THIS FILE EXISTS BECAUSE `lookup.py' IS NOT A FAIR PARTNER FOR THE STORE
LANES. A Python dict is memory: it is not durable, it is not
transactional, no second process can read it, and it disappears when the
interpreter exits. cocolog's `--embed' and server arrangements are a
database -- rows that survive the process, a turn that commits or does
not, and a second process that can read what the first wrote. Comparing
those to a dict measures the guarantees, not the engine, and the
comparison flatters Python for offering less.

So the state-machine table pairs them with the nearest thing every Python
already has: sqlite3, a file on disk, an index on the key, and the build
committed as one transaction. That is a real database against a real
database.

One difference stays and is the point rather than a flaw: SQLite's
PRIMARY KEY builds an index, and cocolog HAS NO CLAUSE INDEXING -- it
tries clauses in order. The gap that opens here is that design
difference, measured.
"""
import sys, sqlite3

def main(n, reps, path):
    db = sqlite3.connect(path)
    db.execute("create table if not exists f (k integer primary key, v integer)")
    db.executemany("insert or replace into f values (?,?)",
                   [(k, (k * 7) % 1000) for k in range(n, 0, -1)])
    db.commit()
    s = 0
    cur = db.cursor()
    for _ in range(reps):
        a = 0
        m = 1000
        while m > 0:
            cur.execute("select v from f where k=?", (((m * 37) % n) + 1,))
            row = cur.fetchone()
            if row is not None:
                a += row[0]
            m -= 1
        s = a
    print("answer(%d)" % s)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
