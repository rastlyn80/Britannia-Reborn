# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin the exact Enhanced sequences for the Matriarch and Swamp Dragons."""

import hashlib
import runpy

MEMBERS = {72: '0x9d080852986b10e2', 794: '0xf4cc25e7a812169e', 799: '0xf31c45be51828c7'}
SPRITES = {
    72: {
        23: ('TerathanMatriarchRearRise', 45, 'dc223516a282b435694fa5b677b7ea6f7c1e1e892f6d1a1d6dafc995bb0ba7b7'),
        26: ('TerathanMatriarchQuietTurn', 55, 'fee71ad7aec57ea1e02d31bd8481aebe2b4cc9fde504677a6a21c55760d7eb0b'),
        27: ('TerathanMatriarchPincerThreat', 55, '480a244a65bd4d11166fe468fa8826f0ba10c0a2fe20e20e83b2cc80d2602fb9'),
        28: ('TerathanMatriarchSideAlert', 30, '3739b823e8d74799e884402f0a96133e7982ad96a4288dc57d35d828e54c4212'),
    },
    794: {
        1: ('SwampDragonWingStand', 45, '9dd14a5ac42065e1ead83d588783180c2b7825438a58ea0a153c3f984e17e9d6'),
        4: ('SwampDragonLowSnap', 40, 'bfddf1cadd48cfdca7f0723bf7c366ef6145012e7d982787787ce98e4d786e94'),
        11: ('SwampDragonWingFlare', 65, '4df5015259ed99090a9bbeb75532ee40c29970a73d5e7e7f1148fffdce406f59'),
        15: ('SwampDragonWingSweep', 30, 'da7771f2cb43eeadac0233e74e96d2345edb29e37086a1528d126820e16362f5'),
        23: ('SwampDragonUnfold', 65, '1334cbb2b53f3b3a414e2a97ea2547eb56d01b4f89d98d4745680128d54d6a97'),
        26: ('SwampDragonHeadCheck', 60, '0184d2e781580f0bdaa602739c179e3a11ce811538f947eb3597590857359bcb'),
        27: ('SwampDragonWingShake', 45, 'ecc52fde82292e4a8143a42df006f7bd4f36e2f85603507ab49d076138ec587f'),
        28: ('SwampDragonWingAlert', 35, '427c3794a11ac7cd061bce1e4a10d1971d72ca2d142e87add93ad61d86caf397'),
        31: ('SwampDragonSeatedStill', 50, '6acd44c24828999f834e502f30850af4e392ab9639c5871af7397c5217c0a2ba'),
    },
    799: {
        11: ('BardedSwampDragonNeckFlare', 65, '7f47e04bb7aa981786cbef6aa862d87c808fafe741de1b1988a1b7be67aa1531'),
        12: ('BardedSwampDragonBraceLunge', 55, '646d13d346b53724015735cb48d9a4cc22feba14b21dbbaf82b76a7e011516db'),
        15: ('BardedSwampDragonLowSweep', 30, '58b0454598c8d088945005ad83291e08f99764fce5e6a7def0a63fd19576d157'),
        23: ('BardedSwampDragonRise', 40, 'b24a6d363983447094de748f6867ac6f75efd38445a8b19a5e40f2daada14ec0'),
        26: ('BardedSwampDragonHeadCheck', 60, '70780d0d65bee0e414518bf8dacc6ee704e79fbec1425de894ccf92838ef9ec8'),
        27: ('BardedSwampDragonTailShake', 45, '5ef510a60cf1b3c5512234aadaeacf91ec481f1cfb5f87dafde79ad1d08e6df8'),
        28: ('BardedSwampDragonAlert', 35, '6778ced0029a80c173b07dc06a939688d9b11563e0895b83869289805075422e'),
        31: ('BardedSwampDragonSeatedStill', 50, 'b821e660c6d2eee576e490f8605a4a73d87606dd35f12105bb6d2907f2279236'),
    },
}

TYPES = {72: (5, 8, 15), 794: (1, 2, 5, 8, 11, 14, 15), 799: (1, 2, 5, 8, 11, 14, 15)}
FORMS = {
    "matriarch": ("TerathanMatriarch", 72, 0, 0x8035, "MageAI"),
    "swamp": ("SwampDragon", 794, 0x851, 0x455, "MeleeAI"),
    "scaled": ("ScaledSwampDragon", 799, 0, 0x8035, "MeleeAI"),
}
RENDERERS = {72: "SourceEnhancedTerathanMatriarchVisual.gd",
             794: "SourceEnhancedSwampDragonVisual.gd", 799: "SourceEnhancedSwampDragonVisual.gd"}


def selectors(root, source, common):
    sha = common["sha"]
    assert sha(source / "AnimationSequence.uop") == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(root / "scripts/uo-enhanced-frames.py"))["read_amou"]
    tables = {}
    for record in inspect(source / "AnimationSequence.uop", set(SPRITES)):
        body = record["animation_ref"]
        if record["uop_name_hash"] != MEMBERS[body]:
            continue
        assert not record["unparsed_bytes"] and body not in tables
        slots = SPRITES[body]
        table, used = {}, set()
        for mode in record["modes"]:
            number = mode["mode"]
            if number == 3:
                assert body == 794 and mode["fallback_mode"] == 0
                assert mode["new_protocol_actions"] == [{"type": 4, "subaction": -1, "groups": [19]}]
                continue
            if number == 2:
                assert body in (794, 799) and mode["fallback_mode"] == 1
                assert mode["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [31]}]
                idle, walk, run = mode["movement"]
                assert [row["action"] for row in (idle, walk, run)] == [0, 1, 2]
                assert [row["one_handed_group"] for row in (idle, walk, run)] == [31, 29, 30]
                assert [row["two_handed_group"] for row in (idle, walk, run)] == [31, 29, 30]
                used.add(31)
                continue
            assert number in (0, 1) and str(number) not in table
            assert mode["fallback_mode"] == (-1 if number == 0 else 0)
            actions = {}
            for action in mode["new_protocol_actions"]:
                kind = action["type"]
                if kind not in TYPES[body]:
                    continue
                assert action["subaction"] == -1 and str(kind) not in actions
                actions[str(kind)] = [slots[group][0] for group in action["groups"]]
                used.update(action["groups"])
            table[str(number)] = actions
        assert table.keys() == {"0", "1"} and used == slots.keys()
        for group, (_, count, digest) in slots.items():
            path = source / f"ec-frame-{body}-{group}.bin"
            assert sha(path) == digest
            identity, frames = decode(path.read_bytes())
            assert identity == body and len(frames) == count and all(frame.group == group for frame in frames)
        tables[body] = table
    assert tables.keys() == SPRITES.keys()
    return tables


def native_receipt(root, folder, name, common):
    read, sha = common["read"], common["sha"]
    path = folder / f"{name}.json"
    receipt = read(folder / f"{name}-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"),
                      (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == receipt[f"{key}_sha256"].lower()
    return read(path), sha(path)


def verify_native(root, stage, folder, tables, terrain, common):
    sha = common["sha"]
    loose = root / "work/creatures/native-matriarch-swamp-dragon-enhanced"
    native, loose_hash = native_receipt(root, loose, "matriarch-swamp-dragon-native", common)
    assert native["checks"] >= 500 and native["records"].keys() == FORMS.keys()
    assert native["test_sha256"] == sha(loose / "NativeMatriarchSwampLive.gd")
    assert native["dispatcher_sha256"] == sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd")
    assert native["inputs_sha256"] == sha(folder / "test-swamp-dragon-enhanced.gd")
    assert native["renderers"] == {str(body): sha(stage / "Viewer/Presentation" / name)
                                   for body, name in RENDERERS.items()}
    for form, (name, body, hue, corpse_hue, ai) in FORMS.items():
        record = native["records"][form]
        assert (record["class"], record["hue"], record["corpse_body"], record["corpse_hue"], record["ai"]) == (
            name, hue, body, corpse_hue, ai)
        assert record["stock_weapon"] == "Fists" and record["tamable"] == (body != 72)
        assert record["can_move"] and not (record["can_swim"] or record["can_fly"])
        assert max(map(abs, record["step_delta"])) == 1 and record["corpse"] >= 0x40000000
        combat, loot = record["combat"], record["carved"]
        if body == 72:
            assert combat["damage"] > 0 and loot["gold"] > 0 and loot["silk"] >= 5
        else:
            packet = combat["packet"]
            assert (packet["protocol"], packet["body"], packet["serial"]) == ("classic", body, record["serial"])
            assert packet["action"] in (4, 5, 6) and combat["clip"]
            if body == 794:
                assert loot["ribs"] >= 19
        phase, = record["phases"]
        assert phase["asset_sha256"] == terrain[body]["hashes"]["modern"]
        cases = phase["cases"]
        expected = {(flag, kind, var) for flag in (0, 64) for kind in TYPES[body] for var in (0, 1, 2, 255)}
        assert len(cases) == len(expected) and {(c["flags"], c["type"], c["variation"]) for c in cases} == expected
        for case in cases:
            mode, kind, variant = ("0" if case["flags"] else "1"), str(case["type"]), case["variation"]
            choices = tables[body][mode].get(kind, tables[body]["0"][kind])
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else case["classic"])
    mounted = root / "work/creatures/native-swamp-ridden-enhanced"
    ridden, ridden_hash = native_receipt(root, mounted, "swamp-ridden-native", common)
    assert ridden["checks"] == 388 and ridden["failures"] == 0
    assert {(case["female"], case["fixture_variant"]) for case in ridden["records"]} == {
        (female, variant) for female in (False, True) for variant in (55, 56, 59)}
    assert len(ridden["records"]) == 6 and all(case["ride_permitted"] for case in ridden["records"])
    assert sha(mounted / "fixtures/EquineFixtures.cs") == sha(root / "Server/HorseIntegrationFixtures/EquineFixtures.cs")
    log = (mounted / "swamp-ridden-native-client.log").read_text(encoding="utf-8-sig")
    for proof, count in (("Server-mounted actor uses the fitted seated idle", 6),
                         ("Fitted seated idle yields to the retained native gait", 12),
                         ("Native barded identity uses its metal treatment", 4)):
        assert log.count(proof) == count
    return hashlib.sha256(
        bytes.fromhex(loose_hash) + bytes.fromhex(ridden_hash)).hexdigest()


def prepare_matriarch_swamp(root, source, common, staged=None):
    stage = staged or root
    read, sha = common["read"], common["sha"]
    folder = root / "work/creatures/native-form-audit/enhanced-source-gaps/terathan-matriarch-swamp-dragons"
    tables = selectors(root, source, common)
    render = read(folder / "motion-render-receipt.json")
    swamp = read(folder / "swamp-runtime-receipt.json")
    dense = read(folder / "matriarch-pincer-receipt.json")
    terrain = {72: read(folder / "matriarch-runtime-receipt.json"),
               **{int(body): proof for body, proof in swamp["bodies"].items()}}
    assert swamp["seat_error"] < .002 and swamp["stirrup_error"] < .025
    assert dense["sample_rate"] == 240 and len(dense["treatments"]) == 3
    for treatment, measurement in dense["treatments"].items():
        assert measurement["scene_sha256"] == terrain[72]["hashes"][treatment]
        assert sum(clip["samples"] for clip in measurement["clips"].values()) == 965
        assert all(clip["crossings"] == 0 and clip["minimum_pincer_distance"] > .46
                   for clip in measurement["clips"].values())
    rows, copies = {}, {}
    for body, slots in SPRITES.items():
        clips = [clip for clip, _, _ in slots.values()]
        motion, views = terrain[body], render[str(body)]
        expected = {72: (1860, 120, 72, 54), 794: (3000, 240, 168, 126), 799: (2625, 210, 168, 126)}[body]
        assert tuple(motion[key] for key in ("poses", "falls", "routes", "classic")) == expected
        assert motion.get("rider_poses", 0) == (0 if body == 72 else 130)
        assert min(motion["gap"], motion["fall_gap"]) >= .0018 and motion["jump"] < .002
        assert views["poses"] == 10 * len(clips) and set(views["clips"]) == set(clips)
        assert views["scene_sha256"] == motion["hashes"]["modern"] and views["minimum_foreground_box_pixels"] > 6800
        assets = {name: folder / f"{body}-{name}.scn" for name in sorted(motion["hashes"])}
        idle = slots[31][0] if 31 in slots else None
        rows[str(body)], local = common["fitted_row"](
            root / "Viewer", body, tables[body], [clip for clip in clips if clip != idle], assets, motion["hashes"])
        if idle is not None:
            rows[str(body)]["mounted_idle"] = idle
        copies.update(local)
    return rows, copies, verify_native(root, stage, folder, tables, terrain, common)

