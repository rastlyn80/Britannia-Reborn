# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
import importlib.util
import json
import runpy
from pathlib import Path

root = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "scripts/prepare-source-preserving.py").is_file())
parser = argparse.ArgumentParser(description="Prepare the preserved Orc Scout mesh and nine Third Dawn clips.")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
script = root / "scripts/prepare-source-preserving.py"
spec = importlib.util.spec_from_file_location("preserving_scout", script)
recipes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipes)
kind = "orcs_orc_scout"
pipeline = recipes.pipeline_for(kind)
pipeline.OUTPUT = args.output.resolve()
pipeline.reuse.RECIPES[kind] = {"floor_sample_rate": 120, "measure_motion_bounds": True}
refine = runpy.run_path(str(root / "scripts/third-dawn-subdivide.py"))["refine"]


def refine_scout(model, **options):
    options.update(levels=2, max_influences=4, weight_smoothing=0.12)
    return refine(model, **options)


pipeline.smooth.refine = refine_scout
pins = json.loads((root / "scripts/source-preserving-inputs.json").read_bytes())
source = next(row for row in pins["models"] if row["kind"] == "orcs_orc_bomber")
rows = pipeline.table_rows(recipes.checked(source["model_table"]).read_bytes())
for row in rows:
    row["stem"] = row["stem"].casefold()
target = next(row for row in rows if row["stem"] == kind)
assert target["body"] == 181 and target["animation_body"] == 140
paths = {record["member"]: recipes.checked(record) for record in source["files"]}
names = {member.casefold(): member for member in paths}


class OriginalInputs:
    def read(self, member):
        return paths[member].read_bytes()


_, native = pipeline.native_bodies()
result = pipeline.prepare("orcs", OriginalInputs(), names, rows, native, selected_kinds={kind})
assert len(result) == 1, result
assert result[0]["status"] == "prepared", result[0]
