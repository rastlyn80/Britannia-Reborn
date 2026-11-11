# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the official Enhanced Seeker references and prepared original-rig scenes."""

import runpy

BODY = 123
MEMBER = "0x2b773a8ac8564a09"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/crystal-lattice-seeker-enhanced"
RENDERER = "SourceEnhancedLatticeSeekerVisual.gd"
PRESENTER = "SourceEnhancedLatticeEventPresenter.gd"
CLIPS = {2: "Death", 3: "Death2", 4: "LatticeRisingStrike", 5: "LatticeCrossingStrike", 10: "LatticeRecoil",
         11: "LatticeWingSearch", 12: "LatticeArcCast", 15: "LatticeWingCover", 22: "LatticePeaceWalk",
         23: "LatticeUnfurl", 25: "LatticeQuietHover", 26: "LatticeNearGlance", 27: "LatticeBroadDisplay",
         28: "LatticeHighWard"}
ATTACKS = {-1: [4, 5, 4, 4, 4, 4], 0: [4, 5, 4], 1: [4], 2: [4], 9: [4]}
ACTIONS = {2: [15, 15], 3: [2, 3], 4: [10], 5: [26, 27], 8: [28], 11: [12, 12, 12],
           14: [11], 15: [23]}
DRAINS = {"1042155": (2, 15, 25, 0x1F8), "1042156": (0, 3, 6, 0x1E6), "1042157": (1, 10, 25, 0x1DF)}

SPRITES = {0: (50, 'c7d69297ec5ca08b7c49d8b7047ad9dfad1cbd1563e67e790c4e6717a65a0a3e'),
 1: (55, '9e4f03087611f59914e4821c7b80be16f1fc4c712334aa655e90761fd6f03210'),
 2: (70, '98159e3b545e5333196e451d7029c4ca175ca2862a4c2a0883a67d9fcb85c845'),
 3: (50, 'a00b926ea5af34fa7916f098f0dfb9f32605ed0f98a37b16df90628d7f38273b'),
 4: (40, '3894819bb49bd9b469245559913d8dbaaef1372fb9fda9a9990d0e5fe2a2f0f8'),
 5: (40, 'ff83ede0ec786b594d11baaafb67bf6ac581f05141e51619ec01e85dc97fa737'),
 10: (35, 'da173b48eb04cc8a7727ee8872f8d3a58c769d4b4164fa6314c1bc602e64feee'),
 11: (55, '6a9740f8e3cfa0b77a140749d577f01ce01bd8aeb3ea988d7c72e3f4f7b66599'),
 12: (45, 'd9bd8dcb8e0a0eb093a29666624c09a21b144c6dfc85522285bf127145706026'),
 15: (30, '7adecd62a21b3acf1caf8087fb2726c20715a28bebee1fcfc4920ea71ef36267'),
 22: (45, 'd114ae054a48ff5032db00d09fbf7596d1978312f7c781dcb4ba378341be3bb8'),
 23: (50, '1aa3a9e596438ff1060efe6adcbaa5b172165461b5ff370fd9f4752f5c19e703'),
 24: (35, '6977583ad373ac400d4e5fb1dbb7888eea7c4ef7fb608f932af247b490684023'),
 25: (60, '54dbdd1a8177ed46fe505dc1dc05705e669e9deda74d138e8a674ba5f24b59e0'),
 26: (55, 'cf339f8b5c87c6c11777b6e7ebf562c6d61f687be4c10d06fd26f523fbb6001c'),
 27: (50, '59938401cc5cb0c9c4220a9b363feb54a2924332048d22f6f89c653a1e216add'),
 28: (65, '51137c2a53198098ed4d12f60028c76596c5909e22e6d97f10753978c1594b82')}


def prepare_crystal_lattice_seeker(root, source, common, staged=None):
    read, sha = common["read"], common["sha"]
    stage = staged or root
    sequence = source / "AnimationSequence.uop"
    assert sha(sequence) == common["SEQUENCE_SHA256"]
    inspect = runpy.run_path(str(root / "scripts/uo-human-sequences.py"))["inspect"]
    decode = runpy.run_path(str(stage / "scripts/uo-enhanced-frames.py"))["read_amou"]
    record, = (row for row in inspect(sequence, {BODY}) if row["uop_name_hash"] == MEMBER)
    assert not record.get("unparsed_bytes")
    combat, peace = record["modes"]
    assert (combat["mode"], combat["fallback_mode"], peace["mode"], peace["fallback_mode"]) == (0, -1, 1, 0)
    for mode, groups in ((combat, (1, 0, 24)), (peace, (25, 22, 24))):
        assert mode["movement"] == [{"action": index, "one_handed_group": group, "two_handed_group": group}
                                    for index, group in enumerate(groups)]
    found = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert found == {(0, subaction): groups for subaction, groups in ATTACKS.items()} | {
        (kind, -1): groups for kind, groups in ACTIONS.items()}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [26]}]
    folder = root / FOLDER
    for group, (count, digest) in SPRITES.items():
        payload = source / f"ec-frame-{BODY}-{group}.bin"
        if not payload.is_file():
            payload = folder / payload.name
        assert sha(payload) == digest
        identity, frames = decode(payload.read_bytes())
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)

    terrain = read(folder / "terrain-receipt.json")
    assert tuple(terrain[key] for key in ("checks", "poses", "falls", "fall_poses")) == (492, 3570, 360, 4320)
    assert terrain["gap"] >= .0015 and terrain["fall_gap"] > 0.0 and terrain["jump"] < .0025
    presentation = stage / "Viewer/Presentation"
    assert terrain["renderer_sha256"] == sha(presentation / RENDERER)
    assert terrain["event_sha256"] == sha(presentation / PRESENTER)
    hashes = terrain["hashes"]
    clips = [CLIPS[group] for group in (3, 4, 5, 10, 11, 12, 15, 23, 25, 26, 27, 28, 22)]
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["poses"] == 130 and render["clips"] == clips and render["minimum_foreground_box_pixels"] > 1700
    assert render["scene_sha256"] == hashes["modern"]
    assets = {treatment: folder / f"{BODY}-{treatment}.scn" for treatment in hashes}
    modes = {"0": {str(kind): [CLIPS[group] for group in groups] for kind, groups in ACTIONS.items()},
             "1": {"5": [CLIPS[26]]}}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, clips, assets, hashes)
    row["attack_subactions"] = {str(key & 255): [CLIPS[group] for group in groups] for key, groups in ATTACKS.items()}
    return {str(BODY): row}, copies, verify_native(root, terrain, read, sha)


def verify_native(root, terrain, read, sha):
    folder = root / "work/creatures/native-crystal-lattice-enhanced"
    path = folder / "crystal-lattice-native.json"
    native, engine = read(path), read(folder / "crystal-lattice-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "CrystalLatticeLive.gd") == native["test_sha256"]
    assert sha(folder / "fixtures/CrystalLatticeFixtures.cs") == native["fixture_sha256"]
    assert native["renderer_sha256"] == terrain["renderer_sha256"]
    assert native["presenter_sha256"] == terrain["event_sha256"]
    assert native["scene_sha256"] == terrain["hashes"]["modern"]
    assert native["checks"] >= 65 and native["corpse"] >= 0x40000000 and native["corpse_gold"] > 0
    assert (native["body"], native["spawn_hue"], native["corpse_hue"], native["ai"], native["weapon"]) == (
        BODY, 0x47E, 0x8035, "MageAI", "Fists")
    for direction in ("outgoing", "incoming"):
        observed = native[direction]
        assert observed.keys() == DRAINS.keys()
        for name, (stat, low, high, sound) in DRAINS.items():
            result = observed[name]
            values = result["gained" if direction == "outgoing" else "lost"]
            assert result["amount"] == values[stat] and low <= result["amount"] <= high
            assert result["damage"] > 0 and result["clients"] == 2 and result["sound"] == sound
    return sha(path)
