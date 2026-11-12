"""Rank broad creature action gaps against the pinned server and spawn catalogue."""

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
BASE_CREATURE = "Projects/UOContent/Mobiles/BaseCreature.cs"
BASE_WEAPON = "Projects/UOContent/Items/Weapons/BaseWeapon.cs"
SPELL = "Projects/UOContent/Spells/Base/Spell.cs"
BODY_TABLE = "Data/bodyTable.cfg"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def source_witness(server, relative, patterns):
    path = server / relative
    source = path.read_text(encoding="utf-8-sig")
    matches = [re.search(pattern, source, re.S) for pattern in patterns]
    if not all(matches):
        raise ValueError(f"Reviewed native source no longer matches: {relative}")
    return {
        "path": relative,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "lines": [source.count("\n", 0, match.start()) + 1 for match in matches],
    }


def body_types(path):
    types = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if not line or line.startswith("#"):
            continue
        body, category, *_ = line.split("\t")
        types[int(body)] = category
    return types


def constructor_occurrences(priority):
    occurrences = defaultdict(list)
    for row in priority["rows"]:
        if row.get("human") or "creature_rank" not in row:
            continue
        for body in row.get("witnessed_constructor_bodies", ()):
            occurrences[body].append({
                "class": row["name"],
                "rank": row["creature_rank"],
                "spawn_locations": row["spawn_locations"],
            })
    return occurrences


def audit(actions, priority, server, table):
    types = body_types(table)
    occurrences = constructor_occurrences(priority)
    missing = [row for row in actions["routes"] if row["resolved"] is None]
    routes = {(row["body"], row["protocol"], row["group_or_type"]): row for row in actions["routes"]}
    witnesses = {
        "approach": source_witness(server, BASE_CREATURE, [
            r"FightMode != FightMode.Aggressor &&\s+FightMode != FightMode.None && Combatant == null && !Controlled && !Summoned && !BardPacified",
            r"InRange\(m.Location, 18\) && !InRange\(oldLocation, 18\)",
            r"if \(Body.IsMonster\)\s*\{\s*Animate\(11, 5, 1, true, false, 1\)",
        ]),
        "weapon_swing": source_witness(server, BASE_WEAPON, [
            r"public virtual void PlaySwingAnimation\(Mobile from\)",
            r"case BodyType.Monster:.*?case WeaponAnimation.ShootBow:\s*\{\s*return;\s*// 7",
            r"case WeaponAnimation.ShootXBow:\s*\{\s*return;\s*// 8",
        ]),
        "cast": source_witness(server, SPELL, [
            r"if \(!caster.Mounted && m_Spell.Info.Action >= 0\)",
            r"else if \(caster.Player && caster.Body.IsMonster\)\s*\{\s*caster.Animate\(12, 7, 1, true, false, 0\)",
        ]),
    }
    approaches = []
    for row in missing:
        body = row["body"]
        if (row["protocol"], row["group_or_type"], types.get(body)) != ("classic", 11, "Monster"):
            continue
        donor = routes.get((body, "classic", 18), {})
        approaches.append({
            "body": body,
            "kind": row["kind"],
            "configured_constructors": sorted(occurrences[body], key=lambda item: item["rank"]),
            "group_18_clip": donor.get("resolved"),
            "group_18_provenance": donor.get("status"),
        })
    approaches.sort(key=lambda row: (
        min((item["rank"] for item in row["configured_constructors"]), default=float("inf")),
        row["body"],
    ))
    return {
        "scope": "Broad ledger gaps and static stock emitter evidence. A source branch and a body type do not prove each class reaches it. Enhanced graph records are separate.",
        "maps": priority["maps"],
        "stock_source": witnesses,
        "runtime_body_table_sha256": hashlib.sha256(table.read_bytes()).hexdigest(),
        "missing": len(missing),
        "missing_by_action": dict(sorted(Counter(row["requested"] for row in missing).items())),
        "matching_classic_source_frame_gaps": len(actions["source_frame_gaps"]),
        "stock_monster_approach_candidates": approaches,
        "missing_monster_player_cast_bodies": sorted({
            row["body"] for row in missing
            if (row["protocol"], row["group_or_type"], types.get(row["body"])) == ("classic", 12, "Monster")
        }),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--occurrence", type=Path)
    args = parser.parse_args()
    root = args.root
    output = root / "outputs/creatures"
    server = root / "Server/ModernUO"
    pin = read_json(root / "Server/dependencies.json")["modernuo"]["revision"]
    revision = subprocess.check_output(
        ["git", "-C", str(server), "rev-parse", "HEAD"], text=True,
    ).strip()
    if revision != pin:
        raise ValueError(f"Expected pinned ModernUO {pin}, found {revision}")
    priority = read_json(args.occurrence or output / "frequency.json")
    if priority["server_pin"] != pin:
        raise ValueError("Occurrence report is from a different ModernUO revision")
    report = audit(read_json(output / "actions.json"), priority, server, root / "Server/runtime" / BODY_TABLE)
    report["server_pin"] = pin
    target = output / "action-gap-audit.json"
    target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{report['missing']} broad gaps, {len(report['stock_monster_approach_candidates'])} stock approach candidates")


if __name__ == "__main__":
    main()
