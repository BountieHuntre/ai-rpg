"""Checks a class design's data: every talent in its own grid slot,
prerequisite lines over empty cells, icons that exist, and builds that follow
the talent rules (5 points a row, prerequisites, 51 points).

    python tools/class_designs/check_design.py docs/class_designs/<class>.json
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main(path):
    d = json.load(open(path, encoding="utf8"))
    problems = []
    talent = {}
    for ti, t in enumerate(d["trees"]):
        cells = {}
        for x in t["talents"]:
            key = (x["row"], x["col"])
            if key in cells:
                problems.append("%s: %s and %s share row %d column %d" % (t["name"], cells[key], x["name"], *key))
            cells[key] = x["name"]
            talent[x["name"]] = (ti, x)
            if x.get("values"):
                for v in x["values"]:
                    if len(v) != x["ranks"]:
                        problems.append("%s: %d values for %d ranks" % (x["name"], len(v), x["ranks"]))
        for x in t["talents"]:
            if x.get("requires"):
                r = talent.get(x["requires"])
                if not r or r[1]["col"] != x["col"]:
                    problems.append("%s: requires %s, not in its column" % (x["name"], x["requires"]))
                    continue
                for row in range(r[1]["row"] + 1, x["row"]):
                    if (row, x["col"]) in cells:
                        problems.append("%s: the line from %s crosses %s" % (x["name"], x["requires"], cells[(row, x["col"])]))
        print("%s: %d talents, %d points" % (t["name"], len(t["talents"]), sum(x["ranks"] for x in t["talents"])))
    keys = {e["icon"] for g in ("abilities", "passives", "mechanics") for e in d.get(g, [])}
    keys |= {x["icon"] for t in d["trees"] for x in t["talents"]}
    for k in sorted(keys):
        if not os.path.exists(os.path.join(ROOT, "assets", "icons", k + ".png")):
            problems.append("no icon " + k)
    for b in d.get("builds", []):
        a = b.get("talents", {})
        per = [0] * len(d["trees"])
        for n, r in a.items():
            if n not in talent:
                problems.append("%s: no talent %s" % (b["name"], n))
                continue
            ti, x = talent[n]
            per[ti] += r
            if r > x["ranks"]:
                problems.append("%s: %s has %d ranks" % (b["name"], n, x["ranks"]))
            below = sum(rr for nn, rr in a.items() if nn in talent and talent[nn][0] == ti and talent[nn][1]["row"] < x["row"])
            if below < (x["row"] - 1) * 5:
                problems.append("%s: %s needs %d points above it, has %d" % (b["name"], n, (x["row"] - 1) * 5, below))
            if x.get("requires") and a.get(x["requires"], 0) != talent[x["requires"]][1]["ranks"]:
                problems.append("%s: %s needs all of %s" % (b["name"], n, x["requires"]))
        if per != b["points"]:
            problems.append("%s: points %s, says %s" % (b["name"], per, b["points"]))
        if sum(per) > 51:
            problems.append("%s: %d points" % (b["name"], sum(per)))
    print("\n".join(problems) if problems else "All good.")
    return not problems


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1]) else 1)
