# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the fitted rabbit, sheep and deer actions against the source and native trial."""

import runpy


SPRITES = {
    205: {
        4: ("RabbitSettleFromRear", 30, "edd2e378f72e4c1cecd6748f62fbaae53fad1f0dac60394b0c068b41c6bfe0e1"),
        25: ("RabbitQuietCrouch", 10, "e5e68f8e65e8b9077eeaac8c80ca520c69b319e50a8ea6057630af2cfc506011"),
        26: ("RabbitLookAround", 40, "0ed14b759fd352b65a744af076e66ac99d5a10ad421d667b9aee70dbcb4e0738"),
        28: ("RabbitRiseAlert", 20, "eaa1c41a0a57f6b77d91a377cffcd4ee208de0b58ee29ac05604006375264d50"),
    },
    207: {
        25: ("SheepQuietStand", 40, "d2836ab28ff06f26c0ccedb8317abce45723ecd3b94d2f1452b49966a74e3cee"),
        26: ("SheepLookDown", 55, "f156dcec9650a265d25ed7083bcd46a5c9189cbdc3fe9f5add937b65ae550434"),
    },
    234: {
        4: ("StagAntlerBow", 30, "3d3874458f9fd8cefa8ff6077ade1937f6ee63b3336960e5c8b594b0780c25aa"),
        15: ("StagRearRecoil", 40, "fc9c3f7b49e91ac9cab598916f2482152c0633b1f4b62e60f2645f78f811a515"),
        25: ("StagQuietStand", 60, "60ca7e83c316c60ba84418953bf09b003ee89cecd726f69ef1188def9aa42dda"),
        26: ("StagAntlerGlance", 40, "3ba9f3ebc4fa2db7b452abca48259774bd418d0971b373e27807e51da9981d65"),
        27: ("StagPawStamp", 25, "6dbb88f9451c597ce7e73b5a0346b8c6bd5f1d7cde2d78d398bfc47493df2082"),
        28: ("StagAntlerAlert", 25, "6fa1c1e4848f3123cf0d9940d9b3437a8938ddb3fa3a8f264f267dfa364eec10"),
    },
    237: {
        4: ("DoeBowThrust", 30, "c344245605c5675a5dd431081705ec7a5d7b11bef25421bfc6a45db5e6b37912"),
        15: ("DoeRearRecoil", 40, "39fe47f1614d29a9f6b9327d4f70b5520f0a30dcc47ff7c54a038ac416d16bab"),
        25: ("DoeQuietStand", 60, "e945cf91560773a3deeb8aee54478664e9679f5a0df96ef6f845d394e551c42e"),
        26: ("DoeGlance", 40, "0c37bb8f0218bad2b42a927e9381a9909281dba6fd6f5c504df21b983c2c2118"),
        28: ("DoeAlert", 25, "54892a6c2dc9fb60fbee35cd804fc919ff5c3501998bdbcc9594454dc480d18b"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
FORMS = {
    "bravehorn": ("Bravehorn", 234),
    "enraged-hart": ("EnragedHart", 234),
    "enraged-hind": ("EnragedHind", 237),
    "enraged-rabbit": ("EnragedRabbit", 205),
    "great-hart": ("GreatHart", 234),
    "hind": ("Hind", 237),
    "jackrabbit": ("JackRabbit", 205),
    "rabbit": ("Rabbit", 205),
    "sheep": ("Sheep", 207),
    "summoned-great-hart": ("SummonedGreatHart", 234),
    "summoned-sheep": ("SummonedSheep", 207),
    "summoned-vorpal-bunny": ("SummonedVorpalBunny", 205),
    "vorpal-bunny": ("VorpalBunny", 205),
}
FULL_FORMS = {"great-hart", "hind", "rabbit", "sheep"}
TERRAIN = {205: 620, 207: 930, 223: 930, 234: 2790, 237: 2325}


def verify_native(path, common, root, groups, bodies, canonical_test):
    sha, read = common["sha"], common["read"]
    folder = path.parent
    native = read(path)
    receipt = read(folder / "field-enhanced-native-runtime.json")
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    assert sha(folder / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll") == receipt["fixture_sha256"].lower()
    assert native["test_sha256"] == sha(folder / "NativeFieldEnhancedLive.gd")
    presentation = root / "Viewer/Presentation"
    assert native["dispatcher_sha256"] == sha(presentation / "EnhancedCreatureActions.gd")
    assert native["inputs_sha256"] == sha(canonical_test)
    assert native["renderers"] == {
        "field": sha(presentation / "SourceEnhancedFieldVisual.gd"),
        "rabbit": sha(presentation / "SourceEnhancedRabbitVisual.gd"),
    }
    assert native["checks"] == 756 and native["records"].keys() == FORMS.keys()
    for form, record in native["records"].items():
        name, first_body = FORMS[form]
        phases = record["phases"]
        assert record["class"] == name and 0 < record["serial"] < 0x40000000
        assert [phase["body"] for phase in phases] == ([207, 223] if form == "sheep" else [first_body])
        assert record["corpse"] >= 0x40000000 and record["corpse_body"] == phases[-1]["body"]
        if form in ("vorpal-bunny", "summoned-vorpal-bunny"):
            assert record["hue"] == 0x480
        if form == "sheep":
            assert phases[-1]["shearing"] == {"unshorn": 207, "shorn": 223, "wool": 1, "native_confirmation": 500452}
        kinds, variants = (TYPES, (0, 1, 255)) if form in FULL_FORMS else ((5,), (1,))
        expected = {(flags, kind, variation) for flags in (0, 64) for kind in kinds for variation in variants}
        for phase in phases:
            body = phase["body"]
            assert phase["asset_sha256"] == bodies[str(body)]["scene_sha256"]["modern"]
            cases = phase["cases"]
            assert len(cases) == len(expected)
            assert {(case["flags"], case["type"], case["variation"]) for case in cases} == expected
            for case in cases:
                kind, variation = str(case["type"]), case["variation"]
                mode = "0" if case["flags"] else "1"
                choices = groups[body][mode].get(kind, groups[body]["0"][kind])
                assert case["classic"] == ""
                assert case["enhanced"] == (choices[variation % len(choices)] if variation <= 127 else "")


def prepare_field(root, source, common):
    sha, read = common["sha"], common["read"]
    scripts, viewer = root / "scripts", root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/field-enhanced"
    groups = common["source_tables"](root, source, SPRITES, TYPES)
    inspect = runpy.run_path(str(scripts / "uo-human-sequences.py"))["inspect"]
    assert not list(inspect(source / "AnimationSequence.uop", {223}))
    shorn = common["base_rows"](viewer)[223]
    assert any(identity["body"] == 223 and identity["animation_body"] == 207 for identity in shorn["bodies"])
    groups[223] = groups[207]

    candidate = read(scenes / "field-enhanced-candidate.json")
    canonical_test = scripts / "test-field-enhanced.gd"
    assert candidate["test_sha256"] == sha(canonical_test)
    assert candidate["bodies"].keys() == {str(body) for body in groups}
    rows, copies = {}, {}
    for body, modes in groups.items():
        result = candidate["bodies"][str(body)]
        treatments = ("modern",) if body == 205 else ("original", "rounded", "modern")
        clips = [clip for clip, _, _ in SPRITES[207 if body == 223 else body].values()]
        assert result["routes"] == 48 * len(treatments)
        assert result["classic_comparisons"] == 36 * len(treatments)
        assert result["terrain_poses"] == TERRAIN[body] and result["corpse_hues"] == 3
        assert result["minimum_by_clip"].keys() == set(clips)
        assert all(.0019 <= gap <= .004 for gap in result["minimum_by_clip"].values())
        assets = {name: scenes / f"{body}-{name}.scn" for name in treatments}
        row, body_copies = common["fitted_row"](viewer, body, modes, clips, assets, result["scene_sha256"])
        rows[str(body)] = row
        copies.update(body_copies)
    path = work / "native-field-enhanced/field-enhanced-native.json"
    verify_native(path, common, root, groups, candidate["bodies"], canonical_test)
    return rows, copies, sha(path)
