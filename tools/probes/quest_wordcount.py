"""Word count of player-facing quest prose, by questline group.

Scratch instrument for the 8/2 terseness pass. Counts `description` plus every
objective `description` - the two fields the journal prints. Pass a git ref to
count that ref instead of the working tree.

    python tools/probes/quest_wordcount.py            # working tree
    python tools/probes/quest_wordcount.py HEAD       # a commit
"""
import collections
import glob
import json
import os
import subprocess
import sys

SEP = os.sep


def group_of(path):
    p = path.replace("\\", "/")
    for k in ("chains", "bounties", "kazan_dun", "temple"):
        if "/%s/" % k in p:
            return k
    for k in ("adventurers", "mages", "mercenaries", "thieves"):
        if "/guild/%s/" % k in p:
            return k
    return "root"


def words(data):
    n = len(data.get("description", "").split())
    for obj in data.get("objectives", []):
        n += len(str(obj.get("description", "")).split())
    return n


def main():
    ref = sys.argv[1] if len(sys.argv) > 1 else None
    counts = collections.Counter()
    files = collections.Counter()
    if ref:
        paths = subprocess.run(
            ["git", "ls-tree", "-r", "--name-only", ref, "data/quests/"],
            capture_output=True, text=True, check=True).stdout.split()
        for path in paths:
            if not path.endswith(".json"):
                continue
            blob = subprocess.run(["git", "show", "%s:%s" % (ref, path)],
                                  capture_output=True, check=True).stdout
            counts[group_of(path)] += words(json.loads(blob.decode("utf-8")))
            files[group_of(path)] += 1
    else:
        for path in glob.glob("data/quests/**/*.json", recursive=True):
            with open(path, encoding="utf-8") as handle:
                counts[group_of(path)] += words(json.load(handle))
            files[group_of(path)] += 1

    for key in sorted(counts):
        print("%-14s %4d files %6d words" % (key, files[key], counts[key]))
    print("%-14s %4d files %6d words" % ("TOTAL", sum(files.values()), sum(counts.values())))


if __name__ == "__main__":
    main()
