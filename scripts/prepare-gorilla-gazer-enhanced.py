# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the fitted Gorilla and Gazer motions against their named Enhanced members."""

import runpy
from pathlib import Path

SPRITES = {
    29: {
        4: ("GorillaOverheadDrop", 55, "b9c967c44f7b44edc9c33fd92db2d49e4d5f1ce67e7676f1868279e4ceeb0092"),
        15: ("GorillaForearmGuard", 35, "2db822e2b63cf0619eb0dc40d7369655e44d8476fc90e0a17d5d9c8a610b03fe"),
        25: ("GorillaLowBreath", 60, "d3702f535a41eb314619e2a8a277d304ad4003fd5a9f440128f10ff662d68815"),
        26: ("GorillaLowWatch", 60, "d8c4d026ca6cff38ef714e2f23139e4e83e68205472feeddbd0d25417603a815"),
        27: ("GorillaChestBeat", 70, "1a73b05d376153a4b34024544707cf371aea66eb72a01159bf9db699ebdf4175"),
        28: ("GorillaArmsWarning", 40, "586799cee29c3b0f74be9ca144618edb97c5991435b116d341cd3fb6445b8939"),
    },
    22: {
        11: ("GazerTentacleSurvey", 65, "fdc759cebd8d970623986490833241afc95bae71a1ea4189201be8956f56da27"),
        12: ("GazerEyeFan", 55, "0cfd054f89f298676a373dedc04545926ed248743f65580324d9bc9d1c6def8a"),
        15: ("GazerTiltRecoil", 30, "1e0e89f0dffb5c0d2430c9f9a4b5d25cf70687a9d46b92342de633aec7487458"),
        23: ("GazerUnfurl", 45, "ac938e530474d77267b15cd2e321b52752be76db19b21981b04fcd004911b4bf"),
        26: ("GazerHoverScan", 65, "3e8e54f9ba0fa05c652a77382096eaf3eea2e0155c1f273e462670f7f0367016"),
        27: ("GazerOrbitFeint", 55, "e1216f69df2b78d68feba58cca39708ea4c728756853022e24b621de86b81ddc"),
        28: ("GazerRaisedEyeAlert", 35, "ad77fe00a6c873cbab6abb308ebbf03e9f5223c6891513966e20cb1c2833c657"),
    },
}
TYPES = (2, 5, 8, 11, 14, 15)
MEMBERS = {29: "0x86b506feb6c3f7e9", 22: "0x598bd09e86a45d8a"}
FORMS = {
    "gorilla": ("Gorilla", 29, (0,), 0x8035),
    "plague-gorilla": ("PlagueSpawn", 29, range(0x11, 0x20), 0x455),
    "gazer": ("Gazer", 22, (0,), 0x455),
    "elder-gazer": ("ElderGazer", 22, (0,), 0x8035),
}
CLASSIC_NEW = {29: {}, 22: {5: ("Fidget", "EyeSpread")}}
CLASSIC_SWING = {29: {4: "Alert", 5: "Attack", 6: "Attack"},
                 22: {4: "Attack", 5: "Attack2", 6: "EyeVolley"}}


def prepare_gorilla_gazer(root, source, common, staged=None):
    sha, read = common["sha"], common["read"]
    viewer = root / "Viewer"
    work = root / "work/creatures"
    scenes = work / "native-form-audit/enhanced-source-gaps/gorilla-gazer"
    code_root = staged or root
    name_hash = runpy.run_path(str(root / "scripts/audit-classic-parity.py"))["name_hash"]
    assert MEMBERS == {body: hex(name_hash(f"build/animationsequence/{body:08d}.bin")) for body in SPRITES}
    groups = common["source_tables"](root, source, SPRITES, TYPES, member_hashes=MEMBERS)
    assert groups[29]["0"]["5"] == ["GorillaLowWatch", "GorillaChestBeat"]
    candidate = read(scenes / "terrain-receipt.json")
    render = read(scenes / "motion-render-receipt.json")
    assert candidate["test_sha256"] == sha(code_root / "scripts/test-gorilla-gazer-enhanced.gd")
    assert candidate["bodies"].keys() == render.keys() == {"29", "22"}
    world = {profile: read(scenes / f"world-{profile}.json") for profile in ("classic", "enhanced")}
    assert all(report.keys() == candidate["bodies"].keys() for report in world.values())
    rows, copies = {}, {}
    for body, table in groups.items():
        result = candidate["bodies"][str(body)]
        fitted = render[str(body)]
        clips = [clip for clip, _, _ in SPRITES[body].values()]
        assert (result["selections"], result["classic"], result["poses"], result["hues"]) == (144, 108, len(clips) * 465, 3)
        assert len(result["falls"]) == 60 and all(fall["jump"] < .002 and fall["gap"] > .0019 for fall in result["falls"])
        assert result["clips"].keys() == set(clips) == set(fitted["clips"])
        assert all(pose["gap"] > .0019 for pose in result["clips"].values())
        assert fitted["poses"] == len(clips) * 8 and fitted["minimum_foreground_box_pixels"] > 2500
        assert fitted["scene_sha256"] == result["hashes"]["modern"]
        if body == 29:
            for action in ("GorillaChestBeat", "GorillaOverheadDrop"):
                pose = result["clips"][action]
                assert pose["highest"] - pose["first"] > .30
            assert result["eye_flashes"] == 0
        else:
            assert result["eye_flashes"] == 12
            unfurl = result["clips"]["GazerUnfurl"]
            assert unfurl["last"] - unfurl["first"] > .95 and unfurl["gap"] > .35
        for profile, report in world.items():
            replay = report[str(body)]
            assert replay["retained"] == (profile == "enhanced" or body == 22) and replay["jump"] < .002
            assert replay["corpse"] >= 0x40000000 and replay["hue"] == (0x8035 if body == 29 else 0x455)
        assets = {name: scenes / f"{body}-{name}.scn" for name in ("original", "rounded", "modern")}
        row, body_copies = common["fitted_row"](viewer, body, table, clips if body == 29 else [], assets, result["hashes"])
        rows[str(body)] = row
        copies.update(body_copies)
    native = work / "native-gorilla-gazer-enhanced/gorilla-gazer-native.json"
    verify_native(root, code_root, scenes, native, candidate, groups, common)
    return rows, copies, sha(native)


def verify_native(root, code_root, scenes, path, candidate, groups, common):
    sha, read = common["sha"], common["read"]
    native = read(path)
    receipt = read(path.with_name("gorilla-gazer-native-runtime.json"))
    assert sha(path) == receipt["report_sha256"].lower()
    assert sha(root / "Server/runtime/Server.dll") == receipt["server_sha256"].lower()
    assert sha(root / "Server/runtime/Assemblies/UOContent.dll") == receipt["content_sha256"].lower()
    fixture = path.parent / "fixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll"
    assert sha(fixture) == receipt["fixture_sha256"].lower()
    assert native["test_sha256"] == sha(path.with_name("NativeGorillaGazerLive.gd"))
    assert native["inputs_sha256"] == candidate["test_sha256"]
    assert native["dispatcher_sha256"] == sha(root / "Viewer/Presentation/EnhancedCreatureActions.gd")
    renderers = {}
    for name in ("gorilla", "gazer"):
        filename = f"SourceEnhanced{name.title()}Visual.gd"
        shadow = scenes / filename
        runtime = code_root / "Viewer/Presentation" / filename
        assert shadow.read_text(encoding="utf-8") == runtime.read_text(encoding="utf-8")
        renderers[name] = sha(shadow)
    assert native["renderers"] == renderers
    verify_cases = runpy.run_path(str(root / "scripts/enhanced-creature-proof.py"))["verify_native_cases"]
    verify_cases(native, 539, FORMS, TYPES, groups, candidate["bodies"], CLASSIC_NEW, CLASSIC_SWING)
