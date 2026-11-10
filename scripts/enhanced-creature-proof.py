# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate controlled Enhanced packets separately from native Classic actions."""


def verify_native_cases(native, checks, forms, types, groups, body_results, classic_new, classic_swing):
    assert native["checks"] == checks and native["records"].keys() == forms.keys()
    expected = {(flags, kind, variant) for flags in (0, 64) for kind in types for variant in (0, 1, 255)}
    for form, record in native["records"].items():
        name, body, hues, dye = forms[form]
        assert record["class"] == name and record["hue"] in hues and record["stock_weapon"] == "Fists"
        assert record["can_move"] and record["corpse_body"] == body and record["corpse_hue"] == dye
        assert record["corpse"] >= 0x40000000
        phase, = record["phases"]
        assert phase["body"] == body and phase["asset_sha256"] == body_results[str(body)]["hashes"]["modern"]
        assert len(phase["cases"]) == len(expected)
        assert {(case["flags"], case["type"], case["variation"]) for case in phase["cases"]} == expected
        for case in phase["cases"]:
            action, variant = case["type"], case["variation"]
            mode = "0" if case["flags"] else "1"
            choices = groups[body][mode].get(str(action), groups[body]["0"][str(action)])
            classic = classic_new[body].get(action, ("", ""))[variant & 1]
            assert case["classic"] == classic
            assert case["enhanced"] == (choices[variant % len(choices)] if variant <= 127 else classic)
        swing = record["swing"]
        packet = swing["packet"]
        assert packet["protocol"] == "classic" and packet["body"] == body and packet["serial"] == record["serial"]
        assert swing["clip"] == classic_swing[body][packet["action"]]
