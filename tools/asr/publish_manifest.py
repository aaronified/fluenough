"""Write asr-manifest.json for the on-device listener packs (#1004, task 11).

Usage:
  python3 -I publish_manifest.py <pack dir> [<pack dir> ...] [--out asr-manifest.json]
      [--pack-version 1] [--base-url URL] [--stage DIR]

Each pack dir is what export_pack.py writes for one language: encoder.int8.onnx,
head_<code>.f32 and head_<code>.json (the code is read from the head file's name). The
manifest is what the app downloads first (lib/app/asr_pack_downloader.dart):

  {"packVersion": 1, "languages": [{"code": "te", "files": [
      {"name": "encoder.int8.onnx", "kind": "encoder", "bytes": N, "sha256": "...", "url": "..."},
      {"name": "head_te.f32", "kind": "head", ...}, {"name": "head_te.json", "kind": "head", ...}]}]}

`name` is the file name the app stores under files/asr/<code>/. Every language's encoder has
the same local name, so the release asset is named `<code>-encoder.int8.onnx`; the heads
already carry the code. The owner creates the `models` release and uploads the assets (no
agent creates tags or releases); --stage copies the files into one folder under their asset
names, ready to upload. Sizes and sha256 are measured here from the files, never trusted
from pack-report.json. Every problem is logged and the exit code is non-zero.
"""
import argparse
import hashlib
import json
import logging
import os
import re
import shutil
import sys

log = logging.getLogger("asr.publish_manifest")

BASE_URL = "https://github.com/aaronified/fluenough/releases/download/models"
ENCODER = "encoder.int8.onnx"
HEAD_RE = re.compile(r"^head_([a-z]{2,3})\.f32$")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def asset_name(code, name):
    """The release asset a pack file is uploaded as."""
    return f"{code}-{name}" if name == ENCODER else name


def language_entry(pack_dir, base_url=BASE_URL):
    """The manifest entry of one pack dir; raises ValueError naming what is wrong."""
    names = os.listdir(pack_dir)
    codes = sorted({m.group(1) for n in names if (m := HEAD_RE.match(n))})
    if len(codes) != 1:
        raise ValueError(f"{pack_dir}: expected exactly one head_<code>.f32, found {codes}")
    code = codes[0]
    wanted = [(ENCODER, "encoder"), (f"head_{code}.f32", "head"), (f"head_{code}.json", "head")]
    files = []
    for name, kind in wanted:
        path = os.path.join(pack_dir, name)
        if not os.path.isfile(path):
            raise ValueError(f"{pack_dir}: missing {name}")
        size = os.path.getsize(path)
        if size == 0:
            raise ValueError(f"{path}: empty file")
        files.append({
            "name": name,
            "kind": kind,
            "bytes": size,
            "sha256": sha256_file(path),
            "url": f"{base_url.rstrip('/')}/{asset_name(code, name)}",
        })
    return {"code": code, "files": files}, [(os.path.join(pack_dir, f["name"]), asset_name(code, f["name"]))
                                            for f in files]


def build(pack_dirs, pack_version=1, base_url=BASE_URL):
    """The manifest dict and the (source path, asset name) pairs to upload."""
    languages, uploads, seen = [], [], set()
    for d in pack_dirs:
        entry, ups = language_entry(d, base_url)
        if entry["code"] in seen:
            raise ValueError(f"language {entry['code']} given twice")
        seen.add(entry["code"])
        languages.append(entry)
        uploads.extend(ups)
    languages.sort(key=lambda e: e["code"])
    return {"packVersion": pack_version, "languages": languages}, uploads


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("packs", nargs="+")
    ap.add_argument("--out", default="asr-manifest.json")
    ap.add_argument("--pack-version", type=int, default=1)
    ap.add_argument("--base-url", default=BASE_URL)
    ap.add_argument("--stage", help="copy the files here under their release asset names")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    try:
        manifest, uploads = build(args.packs, args.pack_version, args.base_url)
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)
            f.write("\n")
        if args.stage:
            os.makedirs(args.stage, exist_ok=True)
            for src, asset in uploads:
                shutil.copyfile(src, os.path.join(args.stage, asset))
    except (OSError, ValueError):
        log.exception("could not write the manifest")
        return 1
    for lang in manifest["languages"]:
        log.info("%s: %d bytes in %d files", lang["code"], sum(f["bytes"] for f in lang["files"]),
                 len(lang["files"]))
    log.info("wrote %s; upload to the `models` release: %s", args.out,
             ", ".join(a for _, a in uploads) + ", " + os.path.basename(args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
