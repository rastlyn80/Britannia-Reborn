# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the two native Shadow Wisp forms and exact Enhanced action references."""

from math import dist
import runpy


BODY = 165
MEMBER = "0xaa70d35798ac1dd5"
FOLDER = "work/creatures/native-form-audit/enhanced-source-gaps/shadow-wisp-enhanced"
RENDERER = "SourceEnhancedShadowWispVisual.gd"
SURFACE = "ShadowWispActionSurface.gdshader"
SPRITES = {1: (55, 'd1fd6d3b12b9bcb48ed69a97012af68fbb7fd6b0cebbe62594064291687d44e8'), 2: (55, '5d34f4f6712a66bcc31fbff29d6bbe9a296bc0a25190d768e98f080a94de0c2f'), 4: (55, '5786d03a3e51343f7926c0d7db4f74ad239b830d15d82b3a71030cc3801ed01d'), 10: (56, '158c91a7399f20e1caa237b27e977bbdba0dcf8cf43ce5d8e870c2945d314a26'), 23: (55, '473eac9a385b6496c8fe56c0c2cd6ed665f5bfe13293b2a7e07b35801b364d1d')}

def sprite_centre(frame):
    width, _ = frame.size
    alpha = frame.rgba[3::4]
    total = sum(alpha)
    assert total
    return (frame.box[0] + sum(index % width * value for index, value in enumerate(alpha)) / total,
            frame.box[1] + sum(index // width * value for index, value in enumerate(alpha)) / total)


def verify_recoil(frames):
    assert [frame.ordinal for frame in frames] == list(range(1, 57))
    first = frames[0]
    assert frames[-1].box == first.box and frames[-1].rgba != first.rgba
    start = sprite_centre(first)
    assert all(dist(sprite_centre(frames[index]), start) < 2 for index in range(0, 56, 11))
    offsets = []
    for index in range(0, 55, 11):
        x, y = sprite_centre(frames[index])
        samples = ((px - x, py - y) for px, py in map(sprite_centre, frames[index:index + 11]))
        offsets.append(max(samples, key=lambda point: dist(point, (0, 0))))
    assert offsets[0][1] < -8 and offsets[4][1] > 12
    assert offsets[2][0] > 16 and offsets[1][0] > 10 and offsets[3][0] > 10


def prepare_shadow_wisp(root, source, common, staged=None):
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
    assert all(row["one_handed_group"] == row["two_handed_group"] == 1
               for mode in (combat, peace) for row in mode["movement"])
    selectors = {(row["type"], row["subaction"]): row["groups"] for row in combat["new_protocol_actions"]}
    assert selectors == {(0, -1): [4] * 6, (0, 0): [4] * 3, (0, 1): [4], (0, 2): [4], (0, 9): [4],
                         (2, -1): [1, 1], (3, -1): [2, 2], (4, -1): [10], (5, -1): [1, 1],
                         (8, -1): [1], (11, -1): [4, 4, 4], (14, -1): [1], (15, -1): [23]}
    assert peace["new_protocol_actions"] == [{"type": 5, "subaction": -1, "groups": [1]}]
    clips = {1: "Idle", 2: "Death", 4: "ShadowWispArc", 10: "ShadowWispRecoil", 23: "ShadowWispKindle"}
    modes = {"0": {str(kind): [clips[group] for group in groups]
                   for (kind, subaction), groups in selectors.items() if subaction == -1}, "1": {"5": ["Idle"]}}
    folder = root / FOLDER
    for group, (count, digest) in SPRITES.items():
        payload = source / f"ec-frame-{BODY}-{group}.bin"
        if not payload.is_file():
            payload = folder / payload.name
        assert sha(payload) == digest
        identity, frames = decode(payload.read_bytes(), directions=1 if group == 10 else 5)
        assert identity == BODY and len(frames) == count and all(frame.group == group for frame in frames)
        if group == 10:
            verify_recoil(frames)
    presentation = stage / "Viewer/Presentation"
    runtime = read(folder / "runtime-receipt.json")
    assert (runtime["checks"], runtime["handoffs"], runtime["routes"]) == (186, 18, 90)
    assert runtime["renderer_sha256"] == sha(presentation / RENDERER)
    assert runtime["surface_sha256"] == sha(presentation / SURFACE)
    render = read(folder / "motion-render-receipt.json")[str(BODY)]
    assert render["clips"] == [clips[group] for group in (4, 10, 23)] and render["poses"] == 30
    assert render["minimum_foreground_box_pixels"] >= 1 and render["scene_sha256"] == runtime["scene_sha256"]
    terrain = read(folder / "terrain-receipt.json")
    assert terrain["scene_sha256"] == runtime["scene_sha256"]
    assert terrain["poses"] == 620 and terrain["minimum_gap"] >= .02 and terrain["maximum_anchor_drift"] < .000001
    assets = {"modern": folder / "165-modern.scn"}
    row, copies = common["fitted_row"](root / "Viewer", BODY, modes, [], assets, {"modern": runtime["scene_sha256"]})
    return {str(BODY): row}, copies, verify_native(root, runtime, read, sha)


def verify_native(root, runtime, read, sha):
    folder = root / "work/creatures/native-shadow-wisp-enhanced"
    path = folder / "shadow-wisp-native.json"
    native = read(path)
    engine = read(folder / "shadow-wisp-native-runtime.json")
    fixture = folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    for file, key in ((path, "report"), (fixture, "fixture"), (root / "Server/runtime/Server.dll", "server"),
                      (root / "Server/runtime/Assemblies/UOContent.dll", "content")):
        assert sha(file) == engine[f"{key}_sha256"].lower()
    assert sha(folder / "NativeShadowWispLive.gd") == native["test_sha256"]
    assert all(native[key] == runtime[key] for key in ("scene_sha256", "renderer_sha256", "surface_sha256"))
    wild, familiar = native["wild"], native["familiar"]
    assert (wild["class"], wild["body"], wild["hue"], wild["corpse_body"], wild["corpse_hue"]) == (
        "ShadowWisp", BODY, 0, BODY, 0x8035)
    assert wild["damage"] > 0 and wild["cast"].endswith("Spell")
    assert wild["motions"] == ["ShadowWispArc", "ShadowWispRecoil", "ShadowWispKindle"]
    assert wild["loot"] in {"LeftArm", "RightArm", "Torso", "Bone", "RibCage", "BonePile"}
    assert (familiar["class"], familiar["body"], familiar["hue"]) == ("ShadowWispFamiliar", BODY, 0x901)
    assert familiar["owned"] and familiar["released"]
    mana = familiar["mana"]
    assert mana["owner_karma"] < 0 < mana["positive_karma"]
    assert mana["negative_gain"] >= mana["expected"] == 1 - int(mana["owner_karma"] / 1000)
    assert 0 <= mana["positive_gain"] <= 1 and mana["familiar_flare"] == mana["caster_flare"] == 0x37C4
    return sha(path)
