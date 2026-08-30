"""The same counting loop, with every addend arriving as a ROW.

The tight loop is the task where the interpreter's per-step price
shows, so the state-machine version makes the store pay per step too:
the addends 1..N are a committed table and every rep sums them one
cursor row at a time -- a hundred thousand rows through the database
per rep, against cocolog's store lanes doing a hundred thousand
inferences beside theirs.
"""
import sys, sqlite3

def main(n, reps, path):
    db = sqlite3.connect(path)
    db.execute("create table if not exists t (k integer primary key)")
    db.executemany("insert or replace into t values (?)",
                   [(k,) for k in range(1, n + 1)])
    db.commit()
    s = 0
    for _ in range(reps):
        a = 0
        for row in db.execute("select k from t"):
            a += row[0]
        s = a
    print("answer(%d)" % s)

if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
