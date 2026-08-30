"""The same naive reverse, with the list living as DURABLE rows.

The pairing rule is lookup_sqlite.py's: cocolog's store lanes run the
algorithm with a database attached and the program's data committed as
rows, so the fair Python partner keeps the same promises -- the input
list is a table, built in one committed transaction, and every rep
reads it back through the database before doing cell-for-cell the same
quadratic work. The reverse itself stays in memory on both sides; what
the store adds here is the durable trip the data makes, not the
algorithm.
"""
import sys, sqlite3

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

def main(n, reps, path):
    db = sqlite3.connect(path)
    db.execute("create table if not exists l (k integer primary key, v integer)")
    db.executemany("insert or replace into l values (?,?)",
                   [(k, k) for k in range(1, n + 1)])
    db.commit()
    c = 0
    for _ in range(reps):
        l = [row[0] for row in db.execute("select v from l order by k")]
        c = sum31(nrev(l))
    print("answer(%d)" % c)

if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])
