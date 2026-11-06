"""Build persona answer files for the Spanish placement bank.

Usage: python3 -I make_answers.py <worktree-root>

Reads (never the key file):
  test/fixtures/placement/banks/es-bank.json
  test/fixtures/placement/personas/es-glossary.json      (known words + glosses)
  test/fixtures/placement/personas/es-expert-truth.json  (expert's own answers, qid -> index)
Writes:
  test/fixtures/placement/answers/es-<persona>-draw<k>.json   qid -> option index (pick) or bool (tiles)
  test/fixtures/placement/answers/es-fidelity.json           per persona/draw accuracy report
"""
import collections, json, random, re, sys, unicodedata
from pathlib import Path

ROOT = Path(sys.argv[1])
FIX = ROOT / "test/fixtures/placement"
bank = json.load(open(FIX / "banks/es-bank.json", encoding="utf-8"))["questions"]
gl = json.load(open(FIX / "personas/es-glossary.json", encoding="utf-8"))
truth = json.load(open(FIX / "personas/es-expert-truth.json", encoding="utf-8"))  # qid -> index, tiles -> 1
amateur_lex = [w for w, v in gl["words"].items() if "lex" in v["lists"]]
amateur_wik = [w for w, v in gl["words"].items() if "wik" in v["lists"]]
beginner = gl["beginner_words"]
KW = {w: [k.lower() for k in v["gloss"]] for w, v in gl["words"].items()}
ARTICLES = ("the ", "a ", "an ", "to ")
PUNCT = re.compile(r"[¿?¡!.,;:\"«»()]")

def norm(s):
    return re.sub(r"\s+", " ", PUNCT.sub(" ", s.lower())).strip()

def toks(s):
    return [t for t in norm(s.replace("____", " ")).split(" ") if t]

def spanish_target(q):
    k = q["promptKind"]
    if k in ("writtenWord", "writtenSentence", "blankSentence"):
        return q.get("prompt")
    if k in ("heardWord", "heardSentence"):
        return q.get("heardText")
    return None

def strip_art(o):
    o = o.lower().strip()
    for a in ARTICLES:
        if o.startswith(a):
            return o[len(a):]
    return o

def lev(a, b):
    p = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        c = [i]
        for j, cb in enumerate(b, 1):
            c.append(min(p[j] + 1, c[j - 1] + 1, p[j - 1] + (ca != cb)))
        p = c
    return p[-1]

def sim(a, b):
    m = max(len(a), len(b)) or 1
    return 1 - lev(a, b) / m

def shared_letters(a, b):
    ca = collections.Counter(c for c in a.lower() if c.isalpha())
    cb = collections.Counter(c for c in b.lower() if c.isalpha())
    return sum((ca & cb).values())

class Persona:
    def __init__(self, name, known, guess_mode):
        self.name = name
        self.known = set(known)
        self.guess_mode = guess_mode  # "random" or "combined"

    def known_all(self, tk):
        return bool(tk) and all(t in self.known for t in tk)

    def glosses(self, tk):
        out = []
        for t in tk:
            if t in self.known:
                out += KW.get(t, [])
        return out

    def pick(self, q, rng):
        opts = q["options"]
        n = len(opts)
        tgt = spanish_target(q)
        if tgt is not None:
            tk = toks(tgt)
            if self.known_all(tk):
                exact = [i for i, o in enumerate(opts) if norm(o) in tk]
                if len(exact) == 1:
                    return exact[0]
                gls = self.glosses(tk)
                m = [i for i, o in enumerate(opts)
                     if any(re.search(r"\b" + re.escape(g) + r"\b", o.lower()) for g in gls)]
                if m:
                    return rng.choice(m)
        else:
            kn = [i for i, o in enumerate(opts) if self.known_all(toks(o))]
            if len(kn) == 1:
                return kn[0]
        if self.guess_mode == "random":
            return rng.randrange(n)
        votes = collections.defaultdict(float)
        text_ok = q["promptKind"] in ("writtenWord", "writtenSentence", "blankSentence")
        if tgt is not None and text_ok:
            ts = norm(tgt)
            sims = [sim(ts, norm(o)) for o in opts]
            top = max(sims)
            win = [i for i, s in enumerate(sims) if s == top]
            for i in win:
                votes[i] += 1 / len(win)
            if any(o.lower() == o.lower() and re.search(r"[a-z]", o.lower()) for o in opts):
                cog = [shared_letters(strip_art(o), ts) for o in opts]
                top = max(cog)
                win = [i for i, s in enumerate(cog) if s == top]
                for i in win:
                    votes[i] += 1 / len(win)
        known_words = self.known
        keys = set()
        for w in known_words:
            for g in KW.get(w, []):
                keys.add(g)
        tkset = set(toks(tgt)) if tgt else set()
        elim = set()
        for i, o in enumerate(opts):
            if strip_art(o) in keys:
                kwmatch = [w for w in known_words if strip_art(o) in KW.get(w, []) and w not in tkset]
                if kwmatch:
                    elim.add(i)
        surv = [i for i in range(n) if i not in elim] or list(range(n))
        for i in surv:
            votes[i] += 1 / len(surv)
        best = max(votes[i] for i in range(n))
        cands = [i for i in range(n) if votes[i] == best]
        return rng.choice(cands)

    def tiles(self, q, rng):
        tiles = q.get("tiles") or []
        if q["promptKind"] == "meaning":
            eng = (q.get("prompt") or "").lower().strip()
            for w in self.known:
                if eng in KW.get(w, []):
                    if not (collections.Counter(w.replace(" ", "")) - collections.Counter("".join(map(str, tiles)).lower())):
                        return True
            return False
        tk = toks(q.get("heardText") or "")
        return self.known_all(tk)

AMATEUR_LEX = Persona("es-amateur-lexodle", amateur_lex, "combined")
AMATEUR_WIK = Persona("es-amateur-wiktionary", amateur_wik, "combined")
BEGINNER = Persona("es-beginner", beginner, "random")

def expert_answers(name, draw, slip_rare, rare_unit, slip_common=0.0):
    rng = random.Random(f"{name}-{draw}")
    out = {}
    for q in bank:
        qid = q["id"]
        if q["mode"] == "tiles":
            ok = True
            if q["unit"] >= rare_unit and rng.random() < slip_rare:
                ok = False
            out[qid] = ok
            continue
        correct = truth[qid]
        if q["unit"] >= rare_unit and rng.random() < slip_rare:
            opts = q["options"]
            others = [i for i in range(len(opts)) if i != correct]
            cw = norm(opts[correct])
            out[qid] = max(others, key=lambda i: (sim(cw, norm(opts[i])), -i))
        else:
            out[qid] = correct
    return out

def persona_answers(p, draw):
    rng = random.Random(f"{p.name}-{draw}")
    out = {}
    for q in bank:
        qid = q["id"]
        if q["mode"] == "tiles":
            out[qid] = p.tiles(q, rng)
        else:
            out[qid] = p.pick(q, rng)
    return out

def score(ans, persona_known):
    rows = []
    for q in bank:
        qid = q["id"]
        if q["mode"] == "tiles":
            correct = True
            got = ans[qid]
            tk_known = persona_known is not None
            rows.append((q, got == correct, q["unit"], q["type"], None))
        else:
            correct = truth[qid]
            got = ans[qid]
            tgt = spanish_target(q)
            known = None
            if persona_known is not None:
                tk = toks(tgt) if tgt else []
                known = bool(tk) and all(t in persona_known for t in tk)
                if tgt is None:
                    known = False
            rows.append((q, got == correct, q["unit"], q["type"], known))
    return rows

def summarise(rows):
    def acc(sel):
        s = [r for r in sel]
        return round(sum(1 for r in s if r[1]) / len(s), 3) if s else None
    bands = {"1-11": lambda u: u <= 11, "12-40": lambda u: 12 <= u <= 40, "41-100": lambda u: 41 <= u <= 100, "101+": lambda u: u > 100}
    by_band = {b: acc([r for r in rows if f(r[2])]) for b, f in bands.items()}
    types = sorted(set(r[3] for r in rows))
    by_type = {t: acc([r for r in rows if r[3] == t]) for t in types}
    known_rows = [r for r in rows if r[4] is True]
    unknown_rows = [r for r in rows if r[4] is False]
    chance = None
    unk_pick = [r for r in unknown_rows if r[0]["mode"] == "pick"]
    if unk_pick:
        chance = round(sum(1 / len(r[0]["options"]) for r in unk_pick) / len(unk_pick), 3)
    return {
        "overall": acc(rows),
        "by_unit_band": by_band,
        "by_type": by_type,
        "known_items": {"n": len(known_rows), "accuracy": acc(known_rows)},
        "unknown_items": {"n": len(unknown_rows), "accuracy": acc(unknown_rows), "chance_pick_items": chance},
    }

if __name__ == "__main__":
    OUT = FIX / "answers"
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    plans = [
        ("expert", None),
        ("native", None),
        ("amateur-lexodle", AMATEUR_LEX),
        ("amateur-wiktionary", AMATEUR_WIK),
        ("beginner", BEGINNER),
    ]
    for label, p in plans:
        for draw in (1, 2, 3):
            if label == "expert":
                ans = expert_answers("es-expert", draw, 0.10, 70)
                known = None
            elif label == "native":
                ans = expert_answers("es-native", draw, 0.05, 130)
                known = None
            else:
                ans = persona_answers(p, draw)
                known = set(p.known)
            fn = OUT / f"es-{label}-draw{draw}.json"
            json.dump(ans, open(fn, "w", encoding="utf-8"), ensure_ascii=False)
            rows = score(ans, known)
            report.setdefault(label, {})[f"draw{draw}"] = summarise(rows)
    json.dump(report, open(OUT / "es-fidelity.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps({k: {d: v["overall"] for d, v in r.items()} for k, r in report.items()}, ensure_ascii=False))
