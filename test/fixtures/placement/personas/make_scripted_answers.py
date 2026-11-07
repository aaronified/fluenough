"""Scripted persona answers for a placement bank (es or hi), from a truth file.

usage:
  python3 -I make_scripted_answers.py --lang es --bank BANK.json --truth TRUTH.json \
      --glossary personas/<lang>-glossary.json --outdir OUT [--ids NEW_IDS.txt] [--draws 1 2 3]

BANK.json: a bank export (keys: questions = [...]).
TRUTH.json: {question_id: correct_option_index} for pick questions (tiles ignored).
  Only the agent running this with the key may produce it; this script never reads a key.
Writes OUT/<lang>-<persona>-draw<k>.json (qid -> index for pick, bool for tiles) and
OUT/<lang>-scripted-fidelity.json (accuracy vs TRUTH by band, type, known/unknown).

Calibration (measured on bank v2, expert and native answers vs the expert's own truth,
per unit band; see personas/README.md):
  expert: units 1-40 slip 0.0; 41-100 slip 0.053; 101+ slip 0.095
  native: units 1-100 slip 0.001; 101+ slip 0.042
A slip replaces the correct option with the option most similar in text (false friend);
a tiles slip marks the item wrong.
Amateur and beginner follow their written rules over the glossary (no truth used).
"""
import argparse, collections, json, random, re, unicodedata
from pathlib import Path

LANG_CFG = {
    "es": {"primary": "lex", "primary_label": "lexodle", "prefix": "es",
           "arts": ("el ", "la ", "los ", "las ", "un ", "una ", "unos ", "unas ", "lo ")},
    "hi": {"primary": "wf", "primary_label": "wordfreq", "prefix": "hi", "arts": ()},
}
ARTICLES = ("the ", "a ", "an ", "to ")
PUNCT = re.compile(r"[¿?¡!.,;:\"«»()।॥]")
EXPERT_SLIP = [(41, 0.053), (101, 0.095)]   # (from unit, rate); units < 41 use 0
NATIVE_SLIP = [(101, 0.042)]                 # units < 101 use 0.001
NATIVE_BASE = 0.001

def norm(s):
    return unicodedata.normalize("NFC", re.sub(r"\s+", " ", PUNCT.sub(" ", s.lower())).strip())

def toks(s):
    return [t for t in norm(s.replace("____", " ")).split(" ") if t]

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

def spanish_target(q):  # Hindi/Spanish: written prompts are the Spanish/Hindi side
    k = q["promptKind"]
    if k in ("writtenWord", "writtenSentence", "blankSentence"):
        return q.get("prompt")
    if k in ("heardWord", "heardSentence"):
        return q.get("heardText")
    return None

def slip_rate(table, unit, base):
    rate = base
    for frm, r in table:
        if unit >= frm:
            rate = r
    return rate

class Persona:
    def __init__(self, name, known, cognate=True, guess="combined"):
        self.name, self.known, self.cognate, self.guess = name, set(known), cognate, guess
    def known_all(self, tk):
        return bool(tk) and all(t in self.known for t in tk)
    def pick(self, q, rng, kw, text_ok_kinds=("writtenWord", "writtenSentence", "blankSentence")):
        opts = q["options"]; n = len(opts); tgt = spanish_target(q)
        if tgt is not None:
            tk = toks(tgt)
            if self.known_all(tk):
                exact = [i for i, o in enumerate(opts) if norm(o) in tk]
                if len(exact) == 1:
                    return exact[0]
                gls = [g for t in tk if t in self.known for g in kw.get(t, [])]
                m = [i for i, o in enumerate(opts) if any(re.search(r"\b" + re.escape(g) + r"\b", o.lower()) for g in gls)]
                if m:
                    return rng.choice(m)
        else:
            kn = [i for i, o in enumerate(opts) if self.known_all(toks(o))]
            if len(kn) == 1:
                return kn[0]
        if self.guess == "random":
            return rng.randrange(n)
        votes = collections.defaultdict(float)
        text_ok = q["promptKind"] in text_ok_kinds
        if tgt is not None and text_ok and self.cognate:
            ts = norm(tgt)
            sims = [sim(ts, norm(o)) for o in opts]
            top = max(sims); win = [i for i, s in enumerate(sims) if s == top]
            for i in win: votes[i] += 1 / len(win)
            cog = [shared_letters(strip_art(o), ts) for o in opts]
            top = max(cog); win = [i for i, s in enumerate(cog) if s == top]
            for i in win: votes[i] += 1 / len(win)
        keys = {g for w in self.known for g in kw.get(w, [])}
        tkset = set(toks(tgt)) if tgt else set()
        elim = set()
        for i, o in enumerate(opts):
            if strip_art(o) in keys and any(strip_art(o) in kw.get(w, []) and w not in tkset for w in self.known):
                elim.add(i)
        surv = [i for i in range(n) if i not in elim] or list(range(n))
        for i in surv: votes[i] += 1 / len(surv)
        best = max(votes[i] for i in range(n))
        return rng.choice([i for i in range(n) if votes[i] == best])
    def tiles(self, q, rng, kw):
        tiles = q.get("tiles") or []
        if q["promptKind"] == "meaning":
            eng = (q.get("prompt") or "").lower().strip()
            for w in self.known:
                if eng in kw.get(w, []):
                    if not (collections.Counter(w.replace(" ", "")) - collections.Counter("".join(map(str, tiles)).lower())):
                        return True
            return False
        return self.known_all(toks(q.get("heardText") or ""))

def scripted_expert(qs, truth, rng, mode):
    out = {}
    for q in qs:
        qid = q["id"]
        if q["mode"] == "tiles":
            rate = slip_rate(EXPERT_SLIP, q["unit"], 0.0) if mode == "expert" else slip_rate(NATIVE_SLIP, q["unit"], NATIVE_BASE)
            out[qid] = rng.random() >= rate
            continue
        correct = truth[qid]
        rate = slip_rate(EXPERT_SLIP, q["unit"], 0.0) if mode == "expert" else slip_rate(NATIVE_SLIP, q["unit"], NATIVE_BASE)
        if rng.random() < rate:
            opts = q["options"]; cw = norm(opts[correct])
            others = [i for i in range(len(opts)) if i != correct]
            out[qid] = max(others, key=lambda i: (sim(cw, norm(opts[i])), -i))
        else:
            out[qid] = correct
    return out

def band(u):
    return "1-40" if u <= 40 else ("41-100" if u <= 100 else "101+")

def score(ans, qs, truth, known_set):
    rows = []
    for q in qs:
        qid = q["id"]
        if q["mode"] == "tiles":
            ok = bool(ans[qid]) is True
        else:
            ok = ans[qid] == truth[qid]
        tgt = spanish_target(q)
        known = None
        if known_set is not None:
            tk = toks(tgt) if tgt else []
            known = bool(tk) and all(t in known_set for t in tk)
        rows.append((q, ok, known))
    def acc(sel):
        return round(sum(1 for r in sel if r[1]) / len(sel), 4) if sel else None
    bands = {b: acc([r for r in rows if band(r[0]["unit"]) == b]) for b in ("1-40", "41-100", "101+")}
    types = {t: acc([r for r in rows if r[0]["type"] == t]) for t in sorted(set(r[0]["type"] for r in rows))}
    kn = [r for r in rows if r[2] is True]; un = [r for r in rows if r[2] is False]
    return {"overall": acc(rows), "by_unit_band": bands, "by_type": types,
            "known_items": {"n": len(kn), "accuracy": acc(kn)},
            "unknown_items": {"n": len(un), "accuracy": acc(un)}}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True, choices=["es", "hi"])
    ap.add_argument("--bank", required=True)
    ap.add_argument("--truth", required=True)
    ap.add_argument("--glossary", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--ids", help="optional file with one question id per line (restrict output)")
    ap.add_argument("--draws", nargs="+", type=int, default=[1, 2, 3])
    a = ap.parse_args()
    cfg = LANG_CFG[a.lang]
    qs = json.load(open(a.bank, encoding="utf-8"))["questions"]
    if a.ids:
        want = set(l.strip() for l in open(a.ids, encoding="utf-8") if l.strip())
        qs = [q for q in qs if q["id"] in want]
    truth = json.load(open(a.truth, encoding="utf-8"))
    missing = [q["id"] for q in qs if q["mode"] == "pick" and q["id"] not in truth]
    assert not missing, ("truth missing ids", missing[:5])
    gl = json.load(open(a.glossary, encoding="utf-8"))
    kw = {w: [k.lower() for k in v["gloss"]] for w, v in gl["words"].items()}
    prim = [w for w, v in gl["words"].items() if cfg["primary"] in v["lists"]]
    wik = [w for w, v in gl["words"].items() if "wik" in v["lists"]]
    beginner = gl["beginner_words"]
    amateur_p = Persona(f"{a.lang}-amateur-{cfg['primary_label']}", prim, cognate=True)
    amateur_nc = Persona(f"{a.lang}-amateur-{cfg['primary_label']}-nocognate", prim, cognate=False)
    amateur_w = Persona(f"{a.lang}-amateur-wiktionary", wik, cognate=True)
    beg = Persona(f"{a.lang}-beginner", beginner, guess="random")
    out = Path(a.outdir); out.mkdir(parents=True, exist_ok=True)
    report = {}
    for draw in a.draws:
        plans = {
            "expert": lambda r: scripted_expert(qs, truth, r, "expert"),
            "native": lambda r: scripted_expert(qs, truth, r, "native"),
        }
        for label, persona in [(f"amateur-{cfg['primary_label']}", amateur_p),
                               (f"amateur-{cfg['primary_label']}-nocognate", amateur_nc),
                               ("amateur-wiktionary", amateur_w), ("beginner", beg)]:
            r = random.Random(f"{persona.name}-{draw}")
            ans = {}
            for q in qs:
                ans[q["id"]] = persona.tiles(q, r, kw) if q["mode"] == "tiles" else persona.pick(q, r, kw)
            plans[label] = (lambda ans: (lambda _r: ans))(ans)
        for label, fn in plans.items():
            r = random.Random(f"{a.lang}-{label}-{draw}")
            ans = fn(r)
            json.dump(ans, open(out / f"{cfg['prefix']}-{label}-draw{draw}.json", "w", encoding="utf-8"), ensure_ascii=False)
            known = set(persona_known(label, prim, wik, beginner, cfg)) if label.startswith(("amateur", "beginner")) else None
            report.setdefault(label, {})[f"draw{draw}"] = score(ans, qs, truth, known)
    json.dump(report, open(out / f"{cfg['prefix']}-scripted-fidelity.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("wrote", len(a.draws) * 6, "answer files to", out)

def persona_known(label, prim, wik, beginner, cfg):
    if label.startswith("amateur-wiktionary"):
        return wik
    if label.startswith("beginner"):
        return beginner
    return prim

if __name__ == "__main__":
    main()
