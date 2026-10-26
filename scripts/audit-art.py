"""Local-only source/replacement inventory and review page. Standard library only."""
import argparse, base64, collections, html, json, pathlib, struct, zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def png_rgba(width, height, data):
    def chunk(name, payload):
        return struct.pack(">I", len(payload)) + name + payload + struct.pack(">I", zlib.crc32(name + payload))
    rows = b"".join(b"\0" + data[y * width * 4:(y + 1) * width * 4] for y in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--dataset", type=pathlib.Path, default=ROOT / "outputs/britain")
    args = parser.parse_args()
    manifest = read(args.dataset / "atlas.json")
    reviews = read(ROOT / "Viewer/Presentation/reviewed-catalog.json")["entries"]
    prepared = args.dataset / "prepared/index.json"
    catalogue = read(prepared)["catalog"] if prepared.exists() else read(ROOT / "Viewer/Presentation/static-catalog.json")["rules"]
    native_path = ROOT / "Server/runtime/Data/UltimaClonePreview/audit.local.json"
    native = read(native_path) if native_path.exists() else {"items": [], "definitions": {}}
    counts, dynamic = collections.Counter(), collections.Counter()
    examples = {}
    for entry in manifest["chunks"]:
        x, y = int(entry["x"]), int(entry["y"])
        data = (args.dataset / f"{x}_{y}.brw").read_bytes()
        magic, sx, sy, w, h, n = struct.unpack_from("<6I", data)
        if magic != 0x31575242 or (sx, sy, w, h) != (x, y, 64, 64) or len(data) != 24 + w*h*3 + n*7:
            raise ValueError("Invalid native chunk")
        for i in range(n):
            graphic, dx, dy, z, hue = struct.unpack_from("<HBBbH", data, 24+w*h*3+i*7)
            counts[graphic] += 1
            examples.setdefault(graphic, [x+dx, y+dy, z])
    for item in native["items"]:
        dynamic[item["id"]] += 1
        examples.setdefault(item["id"], [item["x"], item["y"], item["z"]])
    output = ROOT / "outputs/art-review"
    output.mkdir(parents=True, exist_ok=True)
    originals = output / "original"
    originals.mkdir(exist_ok=True)
    art_path = output / "original-art.local.json"
    if art_path.exists():
        for art in read(art_path):
            (originals / f"{art['id']}.png").write_bytes(png_rgba(art["width"], art["height"], base64.b64decode(art["rgba"])))
    rows = []
    for graphic in sorted(counts.keys() | dynamic.keys(), key=lambda i: -(counts[i] + dynamic[i])):
        key = str(graphic)
        source = manifest["staticData"].get(key, native["definitions"].get(key, {}))
        rule = catalogue.get(key, {})
        review = reviews.get(key, {})
        kind = review.get("kind", rule.get("kind", source.get("family", "unknown")))
        if review.get("asset"):
            rendering = "imported-reviewed-choice"
        elif review:
            rendering = review.get("renderer", "shared-construction")
        elif kind in ("wall", "window", "corner", "roof", "floor", "stairs", "table", "bench", "counter", "prop", "landing", "sign"):
            rendering = "procedural-provisional"
        else:
            rendering = "imported-provisional" if rule.get("asset") else "unresolved"
        rows.append(dict(id=graphic, hex=f"0x{graphic:04X}", name=source.get("name", source.get("display_name", "")), kind=kind,
                         sourceStaticCount=counts[graphic], nativeDecorationCount=dynamic[graphic], example=examples[graphic],
                         actualRenderer=rendering, replacement=review.get("asset", review.get("model", review.get("construction", rule.get("asset", rule.get("model", kind))))),
                         reviewStatus=review.get("reviewStatus", "provisional"), review=review))
    contacts_path = output / "contacts.local.json"
    contacts = read(contacts_path) if contacts_path.exists() else {}
    result = dict(schema=1, sourceStaticIds=len(counts), sourceStaticRecords=sum(counts.values()), nativeDecorationIds=len(dynamic), nativeDecorationRecords=sum(dynamic.values()),
                  catalogueChoices=len(reviews), reviewedIds=sum(r["reviewStatus"] == "reviewed" for r in rows), entries=rows, contacts=contacts)
    (output / "inventory.local.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    content = ["<!doctype html><meta charset='utf-8'><title>Britannia Reborn — local art review</title><style>body{background:#172128;color:#e6ded0;font:15px system-ui;margin:28px}table{border-collapse:collapse;width:100%}td,th{padding:10px;border-bottom:1px solid #465056;text-align:left}img{width:120px;height:100px;object-fit:contain}input{padding:10px;width:60%;margin-bottom:20px}small{color:#a8bbb5}a{color:#dec68f}.views img{width:46%;height:auto;margin:1%}</style>",
               "<h1>Local source and replacement review</h1><p>Original game references and geography: local inspection only. Do not redistribute this report.</p>",
               f"<p>{len(counts)} static IDs / {sum(counts.values()):,} source placements; {len(dynamic)} native-decoration IDs / {sum(dynamic.values())} saved placements. Catalogue coverage is not visual approval.</p>",
               "<h2>Reference block: before and current inspection</h2><div class='views'>"]
    for name in ["tavern", "games", "basement", "inn-room", "street", "inn-street", "bedroom", "landscape", "riverbank", "bridge"]:
        for label in ["before", "after"]:
            if (output / label / f"{name}.png").exists():
                content.append(f"<img loading='lazy' src='{label}/{name}.png' title='{label}: {name}'>")
    content += ["</div><h2>Graphic catalogue</h2><input placeholder='Filter ID, name, kind or review status' oninput=\"for(let r of document.querySelectorAll('tbody tr'))r.hidden=!r.textContent.toLowerCase().includes(this.value.toLowerCase())\"><table><thead><tr><th>Native reference</th><th>Selected model turntable</th><th>ID / source</th><th>Replacement / policy</th></tr></thead><tbody>"]
    for row in rows:
        graphic, review = row["id"], row["review"]
        original = f"<img loading='lazy' src='original/{graphic}.png'>" if (originals / f"{graphic}.png").exists() else "<small>Reference extraction pending</small>"
        model = pathlib.PurePosixPath(str(row["replacement"])).stem
        candidate = f"<img loading='lazy' src='candidates/{model}.png'>" if (output / "candidates" / f"{model}.png").exists() else "<small>Shared construction / pending model view</small>"
        summary = html.escape(f"{row['hex']} / {graphic} · {row['name']} · {row['kind']} · statics {row['sourceStaticCount']} / native {row['nativeDecorationCount']}")
        policy = html.escape(f"{row['replacement']} | {row['reviewStatus']} | {review.get('attachment', 'unreviewed')} | {review.get('materialPolicy', 'provisional')}")
        content.append(f"<tr><td>{original}</td><td>{candidate}</td><td>{summary}</td><td>{policy}</td></tr>")
    content.append("</tbody></table><h2>Support findings</h2><p>Candidate findings need contextual inspection. A source anomaly may already be suppressed by reconstruction. No speculative snapping is applied to unresolved supports.</p><pre>"+html.escape(json.dumps(contacts.get("counts", {}), indent=2))+"</pre>")
    geometry = collections.Counter(x["category"] for x in contacts.get("geometryCandidates", []))
    content.append("<h2>Source geometry candidates</h2><p>These are source-level warnings, not confirmed rendered defects. Full XYZ findings remain in contacts.local.json.</p><pre>"+html.escape(json.dumps(geometry, indent=2))+"</pre>")
    (output / "review.html").write_text("\n".join(content), encoding="utf-8")
    print(f"ART INVENTORY PASS: {len(rows)} distinct static/native IDs; local report: {output / 'review.html'}")

if __name__ == "__main__":
    main()
