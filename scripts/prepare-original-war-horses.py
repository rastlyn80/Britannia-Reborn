"""Build the original Silver, faction, Ethereal and Pack Horse scenes."""

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import runpy
from shutil import copyfile
from struct import unpack
import subprocess
from tempfile import TemporaryDirectory
from types import SimpleNamespace


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(parent for parent in SCRIPTS.parents if (parent / "Viewer/project.godot").is_file())
ART = ROOT / "Viewer/local-art/mounts"
MANIFEST = "original-war-horses.json"
ASSETS = (
    "silver-steed-breath.scn", "war-horse-enhanced.scn", "pack-horse-enhanced.scn",
    "horse-115.png", "horse-119.png", "horse-120.png", "horse-121.png",
)
HORSE = runpy.run_path(str(SCRIPTS / "prepare-dark-horse-mounts.py"))
PACK = runpy.run_path(str(ROOT / "scripts/recover-pack-llama.py"))
RIGID = runpy.run_path(str(ROOT / "scripts/creature-rigid-parts.py"))
GRANNY, REFINE = HORSE["GRANNY"], HORSE["REFINE"]
ATLAS = "equines_horse_dappled_brown_pack.tga"
FORMS = {
    117: (0x3ea8, 'silver_steed', '05e971e625b067bfa73f69aba601e66dd93df3802ff61eddd73c007ccea754a5',
          '718329b91da839702c2a6006bcc5cbba5363019475ff32c494cc26929ffdc7af'),
    118: (0x3eb2, 'war_brittanian', '7aae1225b6ba93f01e346e32cda32825001f1e96c7fb69641e032fafcaecd005',
          '81262ca5dbfb375afd706878f1436f3e812d3aed33c4148471cfcf6038c0c131'),
    119: (0x3eb1, 'war_mage_council', '1f482dd40b4ff1594fd6a072839c201b4cb8c292e8d756832018c55d2754e526',
          '1def169234399d5e060fb70e6c3e3e997ae7ced3da0ddab4646c551b609a941d'),
    120: (0x3eaf, 'war_minax', 'cb9e5659ad5160b6c59385e97754349c20558ebc1b6147707e9d5ee8cd94e161',
          '6c8fc79da4ac711f91e7e62f7288c29d8fc29ee6bd8e253e02c72b4d9d833432'),
    121: (0x3eb0, 'war_shadowlord', '5b02815411e3fac877dc8e019bc1969a609b4036a6fc947bbb176612150b054e',
          'f510d968225f95fb21f6f07291f30bae77ef9dde75c8b680c87edf96d2e09a81'),
    115: (0x3eaa, 'ethereal', 'c8e55d6986c4c526746fe7f0b72f9f807934623eebef850ac745ded3acc60080',
          'b4f09324b4a9a172e80e2599c504e4977ad4126ac850d66fa1468e86fabc2805'),
}


def export_horses(source, study):
    members = {}
    verified = HORSE['verified']
    raw_table = verified(source, 'models.txt', HORSE['MODEL_TABLE'], members)
    clips = {}
    for clip, (name, digest) in HORSE['DONOR'].items():
        path = f'Animals/equines_horse_dappled_brown_{name}.grn'
        clips[clip] = GRANNY['parse'](verified(source, path, digest, members))
        assert len(clips[clip]['tracks']) == 36
    signatures = {}
    records = {}
    for body, (item, name, model_hash, atlas_hash) in FORMS.items():
        stem = f'equines_horse_{name}'
        assert f'{body}\t2\t200\tFFFFFFFF\t0\t1.5\t1.5\t1.5\t{stem}'.encode() in raw_table
        mesh = GRANNY['parse'](verified(source, f'Animals/{stem}_lod2.grn', model_hash, members))
        assert (len(mesh['points']), len(mesh['polygons']), len(mesh['bones'])) == (223, 442, 37)
        assert mesh['textures'] == [stem + '.tga']
        png = GRANNY['png_from_tga'](verified(source, f'Maps/{stem}.tga', atlas_hash, members))
        layout = {key: mesh[key] for key in ('points', 'polygons', 'bones', 'ties', 'weights', 'uv_sets',
                                              'texture_polygons', 'normals')}
        geometry_pin = sha256(json.dumps(layout, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        signatures.setdefault(geometry_pin, []).append(body)
        rounded, refinement = REFINE(mesh, levels=2, maximum=.045,
                                    strengths=HORSE['refinement_strengths'](mesh), weight_smoothing=.16)
        assert rounded['bones'] == mesh['bones']
        record = {'item': item, 'named_source': stem, 'historical_body': body, 'animation_body': 200,
                  'scene_role': 'worn-item spectral variant' if body == 115 else 'loose and ridden',
                  'refinement': refinement, 'scenes': {}}
        for style, geometry in [('original', mesh), ('rounded', rounded)]:
            output = study / f'body-{body}-{style}.gltf'
            metadata = GRANNY['export_gltf'](geometry, clips, png, output, 1.85, measure_motion_bounds=True)
            record['scenes'][style] = dict(metadata, sha256=sha256(output.read_bytes()).hexdigest())
        records[body] = record
        print(body, stem, 'original and refined, 37 joints and eight original motions', flush=True)
    if sorted(sorted(group) for group in signatures.values()) != [[115, 117], [118, 119, 120, 121]]:
        raise ValueError("The shared rigs and UV layouts differ from the verified geometry.")
    (study / 'source.json').write_text(json.dumps({'members': members, 'forms': records,
        'exact_geometry_groups': signatures}, indent=2) + '\n', encoding='utf-8')


def split_meshes(raw):
    filtered = [[], []]
    mesh, material = -1, None
    object_ids = []
    for tag, payload, parents in GRANNY['chunks'](raw):
        if tag == 0xca5e0601:
            mesh += 1
        if tag == 0xca5e0f04 and 0xca5e0601 in parents:
            object_ids.append(unpack('<I', payload)[0])
        if tag == 0xca5e0e02:
            material, count = unpack('<II', payload)
            assert material in (0, 1) and count == 1
        if tag == 0xca5e0e04 and 0xca5e0e02 in parents:
            assert unpack('<I', payload) == (0,)
        entry = (tag, payload, parents)
        if tag == 0xca5e0601 or 0xca5e0601 in parents:
            filtered[mesh].append(entry)
        elif tag in (0xca5e0e02, 0xca5e0e06):
            filtered[1 - material].append(entry)
        else:
            for target in filtered:
                target.append(entry)
    assert object_ids == [1, 42] and mesh == 1
    return filtered


def decode(raw, donor_raw):
    skin_chunks, cargo_chunks = split_meshes(raw)
    parse = GRANNY['parse']
    namespace = parse.__globals__
    original_chunks = namespace['chunks']
    try:
        namespace['chunks'] = lambda _: iter(skin_chunks)
        body = parse(raw, scene_root_names=True)
    finally:
        namespace['chunks'] = original_chunks
    donor = parse(donor_raw, scene_root_names=True)
    skin_tag = 0xca5e0702
    skin, = [payload for tag, payload, _ in skin_chunks if tag == skin_tag]
    donor_skin, = [payload for tag, payload, _ in original_chunks(donor_raw) if tag == skin_tag]
    body_names = [body['bones'][bone]['name'] for bone in body['ties']]
    donor_names = [donor['bones'][bone]['name'] for bone in donor['ties']]
    assert skin == donor_skin and body_names == ['equines_horse_pack', *donor_names]
    assert body['weights'] == donor['weights'] and body['polygons'] == donor['polygons']
    assert body['textures'] == [ATLAS] and len(body['bones']) == 38
    cargo_bone = body['bones'][body['ties'][0]]
    assert body['ties'][0] == 5 and body['bones'][cargo_bone['parent']]['name'] == 'bip01 spine'
    part_reader = SimpleNamespace(chunks=lambda _: iter(cargo_chunks), parse=lambda *_args, **_opts: body,
                                  require=GRANNY['require'], finite=GRANNY['finite'])
    cargo, _, report = RIGID['read_rigid_parts'](raw, part_reader, excluded_names=())
    assert cargo['weights'] == [[(0, 1.)]] * 20 and len(cargo['polygons']) == 36
    # Index zero in the original skinned block refers to the ordinary body
    # palette. The pack scene prepends the rigid cargo tie to its global palette.
    body['weights'] = [[(index + 1, weight) for index, weight in point] for point in body['weights']]
    assert all(0 < index < len(body['ties']) for point in body['weights'] for index, _ in point)
    report['body_palette'] = {'source_skin_sha256': sha256(skin).hexdigest(), 'offset_into_global_ties': 1}
    return body, cargo, report


def export_pack_horse(source, study):
    verify = HORSE['verified']
    members = {}
    table = verify(source, 'models.txt', HORSE['MODEL_TABLE'], members)
    assert b'291\t2\t200\tFFFFFFFF\t0\t1.5\t1.5\t1.5\tequines_horse_dappled_brown_pack' in table
    raw = verify(source, 'Animals/equines_horse_dappled_brown_pack_lod2.grn',
                 'd3bac61a78bbc21bf1c440c86e82edf8bb623eaaac9c22610d8fbbe8019840a1', members)
    donor = verify(source, 'Animals/equines_horse_dappled_brown_lod2.grn',
                   'b1d6dcecdee141e047c3503f53c41ba0f6f31fef843bedcd09c7811b6b6d301c', members)
    atlas = verify(source, f'Maps/{ATLAS}', '80ccbaf548ee92bdeebe7f57cb6ce696b900937e2962e8fbc3cf46757065a205', members)
    body, cargo, report = decode(raw, donor)
    clips = {}
    for clip, (name, digest) in HORSE['DONOR'].items():
        path = f'Animals/equines_horse_dappled_brown_{name}.grn'
        clips[clip] = GRANNY['parse'](verify(source, path, digest, members), scene_root_names=True)
    rounded, refinement = REFINE(body, levels=2, maximum=.045,
                                strengths=HORSE['refinement_strengths'](body), weight_smoothing=.16)
    texture = GRANNY['png_from_tga'](atlas)
    exports = {}
    for treatment, geometry in [('original', body), ('rounded', rounded)]:
        path = study / f'body-291-{treatment}.gltf'
        result = GRANNY['export_gltf'](PACK['with_load'](geometry, cargo), clips, texture, path, 1.85)
        PACK['separate_load'](path, len(geometry['polygons']))
        document = json.loads(path.read_text(encoding='utf-8'))
        document['materials'][0]['name'] = 'Third Dawn Horse Coat'
        document['materials'][1]['name'] = 'Third Dawn Horse Cargo'
        path.write_text(json.dumps(document, separators=(',', ':')), encoding='utf-8')
        exports[treatment] = dict(result, sha256=sha256(path.read_bytes()).hexdigest())
    report.update(body=291, worn_item=None, members=members, refinement=refinement, exports=exports)
    (study / 'pack-horse-source.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Pack Horse 291: original 36-triangle cargo on its own joint, preserved 38-joint rig and eight source gaits and actions')


def asset_hash(path):
    return sha256(path.read_bytes()).hexdigest()


def check_installed(destination=ART):
    manifest = json.loads((destination / MANIFEST).read_text(encoding="utf-8"))
    if manifest.get("schema") != 1 or set(manifest) != {"schema", *ASSETS}:
        raise ValueError("The original horse manifest has an unexpected format.")
    for member in ASSETS:
        if asset_hash(destination / member) != manifest[member]:
            raise ValueError(f"The original horse asset differs from its manifest: {member}")


def install(study, destination=ART):
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temporary:
        staged = Path(temporary)
        for name in ASSETS:
            copyfile(study / name, staged / name)
        manifest = {"schema": 1, **{name: asset_hash(staged / name) for name in ASSETS}}
        (staged / MANIFEST).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        check_installed(staged)
        for name in (*ASSETS, MANIFEST):
            (staged / name).replace(destination / name)
    check_installed(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, help="Private Third Dawn Models directory")
    parser.add_argument("--study", type=Path, default=ROOT / "work/creatures/original-war-horse-bake")
    parser.add_argument("--godot", type=Path, help="Godot 4 console executable")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true")
    mode.add_argument("--check-installed", action="store_true")
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
        print("Original horse scenes and atlases verified.")
        return
    if args.models is None or not (args.models / "models.txt").is_file():
        parser.error("Supply the private Models directory with --models.")
    godot = args.godot or next((ROOT / ".tools/godot").glob("*console.exe"), None)
    if godot is None or not godot.is_file():
        parser.error("Supply the local Godot 4 console executable with --godot.")
    source = args.models.resolve()
    study = args.study.resolve()
    if study.is_relative_to(source):
        parser.error("Use a separate output directory for generated art.")
    study.mkdir(parents=True, exist_ok=True)
    export_horses(source, study)
    export_pack_horse(source, study)
    profile = study / "godot-user"
    profile.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    engine = [str(godot.resolve()), "--headless", "--path", str(ROOT / "Viewer")]
    prepared = study / "prepared"
    scripts = (
        ("check-war-horse-sources", study, []),
        ("bake-dark-horse-breath", prepared, ["--silver"]),
        ("bake-war-horse-enhanced", prepared, []),
    )
    for script, folder, extra in scripts:
        subprocess.run([*engine, "--log-file", str(study / f"{script}.log"), "--script",
                        str(SCRIPTS / f"{script}.gd"), "--", f"--study={folder.as_posix()}", *extra],
                       env=env, check=True, timeout=180)
    if not all((prepared / name).is_file() for name in ASSETS):
        raise RuntimeError("The source build did not emit every expected scene and atlas.")
    if args.install:
        install(prepared)
    print(f"Original horse scenes and atlases prepared in {prepared}.")


if __name__ == "__main__":
    main()
