"""Build optional local Nightmare and Fire Steed scenes from Third Dawn assets."""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import runpy
from shutil import copyfile
import subprocess
from tempfile import TemporaryDirectory


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(folder for folder in SCRIPTS.parents if (folder / "Viewer/project.godot").is_file())
ART = ROOT / "Viewer/local-art/mounts"
SCENES = ("nightmare-breath.scn", "firesteed-breath.scn")
MANIFEST = "dark-horses.json"
MODEL_TABLE = "bac2a817c30773a0d3c1943b61555df4373a0eadbc1b10dfbc94f55d1615b97a"
GRANNY = runpy.run_path(str(ROOT / "scripts/import-third-dawn.py"))
REFINE = runpy.run_path(str(ROOT / "scripts/third-dawn-subdivide.py"))["refine"]
FORMS = {
    "nightmare": {
        "bodies": {116: 0x3EA7, 178: 0x3EA9, 179: 0x3EB7},
        "mesh": "01d5b08915798c8f3e83a12dc83d91a49188ac09347a4b12a51ef7591e15e496",
        "atlas": "b1f573dc5c3b40c2f2e27c4ff281833d08097ced5f15cf8362151f6879e78dd4",
    },
    "firesteed": {
        "bodies": {190: 0x3E9E},
        "mesh": "6ddb2f51662c3bd292f8179400b5146914d22c7350f986a05bd58e8cc6805c78",
        "atlas": "481a201fdb5ebc15852afa23611fb0bd5f2c90bfac84ab21e62edad503e9d596",
    },
}
DONOR = {
    "Idle": ("idle", "6ba69df7f0383591a061cca83e13c96d12b2171c381ce64f7e9ef1e3dffec0ad"),
    "Walk": ("walk", "643f1593589a79cb2b30dfa07cfa98f6346eace66b77b9768bf6a1bcea3bf6c2"),
    "Run": ("run", "ab745cc70db4ab6bf377b090c8dbb17aa0084e96e9b26b4b2ed431eddc008b55"),
    "Attack": ("attack1", "585f5f5cf152f43ee5ebae42ef1f3e48a724945b3b9b574d6937b19054f7c2ab"),
    "Hit": ("gethit", "133c701d5aa26dfa887f98b905043c7e235c0e589a92e59cc9c249941419698f"),
    "Death": ("die1", "704a5fb37cb53946769c98c39d2cb2df38b315c92ad3d64121f4c77415c277e3"),
    "Fidget": ("fidget", "1d1d46fb3db10b768a30f69c222e77284e332ca0dc8174a2b84711592dc94b87"),
    "Eat": ("eat", "7a539258597e5d19fee01dcc980890010d005bada5a1a2ce55240a6d4b3965f1"),
}


def verified(source, name, expected, receipt):
    path = source / name
    data = path.read_bytes()
    actual = sha256(data).hexdigest()
    if actual != expected:
        raise ValueError(f"The original cabinet member changed: {name}.")
    receipt[name] = actual
    return data


def refinement_strengths(mesh):
    strengths = []
    for point in mesh["points"]:
        # Feet retain their original ground contacts, and the muzzle silhouette
        # keeps more of its original shape than the broad barrel of the horse.
        height_weight = max(0.0, min(1.0, (point[2] - .05) / .42))
        muzzle_weight = .4 if point[1] < -.83 else 1.
        strengths.append(height_weight * muzzle_weight)
    return strengths


def export_sources(source, study):
    members = {}
    table = verified(source, "models.txt", MODEL_TABLE, members).decode("ascii")
    associations = {int(row[0]): (int(row[2]), row[8]) for line in table.splitlines()
                    if (row := line.split("\t"))[0].isdigit() and len(row) > 8}
    for name, form in FORMS.items():
        for body in form["bodies"]:
            if associations[body] != (200, f"equines_horse_{name}"):
                raise ValueError(f"Body {body} no longer uses its declared body-200 motion.")
    clips = {}
    for label, (name, digest) in DONOR.items():
        filename = f"Animals/equines_horse_dappled_brown_{name}.grn"
        clip = GRANNY["parse"](verified(source, filename, digest, members))
        if len(clip["tracks"]) != 36:
            raise ValueError(f"Unexpected track count in {filename}.")
        clips[label] = clip
    forms = {}
    for name, form in FORMS.items():
        mesh_path = f"Animals/equines_horse_{name}_lod2.grn"
        atlas_path = f"Maps/equines_horse_{name}.tga"
        mesh = GRANNY["parse"](verified(source, mesh_path, form["mesh"], members))
        if (len(mesh["points"]), len(mesh["polygons"]), len(mesh["bones"])) != (223, 442, 37):
            raise ValueError(f"Unexpected geometry or skeleton in {mesh_path}.")
        if mesh["textures"] != [Path(atlas_path).name]:
            raise ValueError(f"Unexpected texture dependency in {mesh_path}.")
        png = GRANNY["png_from_tga"](verified(source, atlas_path, form["atlas"], members))
        rounded, recipe = REFINE(mesh, levels=2, maximum=.045, strengths=refinement_strengths(mesh),
                                 weight_smoothing=.16)
        if rounded["bones"] != mesh["bones"]:
            raise ValueError("The subdivision changed the original rig.")
        forms[name] = {"native_body_items": form["bodies"], "refinement": recipe, "scenes": {}}
        for style, geometry in (("original", mesh), ("rounded", rounded)):
            path = study / f"{name}-{style}.gltf"
            result = GRANNY["export_gltf"](geometry, clips, png, path, 1.85, measure_motion_bounds=True)
            forms[name]["scenes"][style] = {"sha256": sha256(path.read_bytes()).hexdigest(), **result}
            print(f"{name}/{style}: {result['triangles']} triangles, {result['bones']} joints, {len(result['clips'])} clips.")
    report = {"source": "Later Third Dawn / Age of Shadows cabinet extraction",
              "motion": "Models/models.txt assigns both forms to body 200; the donor is dappled-brown horse.",
              "members": members, "forms": forms}
    (study / "third-dawn-source.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def check_installed(destination=ART):
    manifest = json.loads((destination / MANIFEST).read_text(encoding="utf-8"))
    if manifest.get("schema") != 1 or set(manifest) != {"schema", *SCENES}:
        raise ValueError("The local dark horse manifest does not identify both scenes.")
    for name in SCENES:
        if sha256((destination / name).read_bytes()).hexdigest() != manifest[name]:
            raise ValueError(f"The installed dark horse scene changed: {name}.")


def install(study, destination=ART):
    manifest = {"schema": 1}
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temporary:
        staged = Path(temporary)
        for name in SCENES:
            copyfile(study / name, staged / name)
            manifest[name] = sha256((staged / name).read_bytes()).hexdigest()
        (staged / MANIFEST).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        check_installed(staged)
        for name in SCENES:
            (staged / name).replace(destination / name)
        (staged / MANIFEST).replace(destination / MANIFEST)
    check_installed(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, help="Private Third Dawn Models directory")
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/dark-horses-bake")
    parser.add_argument("--godot", type=Path)
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument("--install", action="store_true")
    operation.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
        print("Dark horse mounts: both installed local scenes verified.")
        return
    if args.models is None or not (args.models / "models.txt").is_file():
        parser.error("Supply the private Models directory with --models.")
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    source = args.models.resolve()
    study = args.study.resolve()
    if study.is_relative_to(source):
        parser.error("Use a separate output directory for the generated art.")
    study.mkdir(parents=True, exist_ok=True)
    export_sources(source, study)
    profile = study / "godot-user"
    profile.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    engine = [str(godot.resolve()), "--headless", "--path", str(ROOT / "Viewer")]
    for script, extra in [("check-dark-horse-sources", ["--pack"]), ("bake-dark-horse-breath", [])]:
        subprocess.run([*engine, "--log-file", str(study / f"{script}.log"), "--script",
                        str(SCRIPTS / f"{script}.gd"), "--", f"--study={study.as_posix()}", *extra],
                       env=env, check=True, timeout=150)
    if args.install:
        install(study)
    print(f"Dark horse mounts: two source-rig scenes prepared in {study}.")


if __name__ == "__main__":
    main()
