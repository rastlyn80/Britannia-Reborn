"""Create reviewed build-only overlays without modifying the pinned checkout.

Only the repository's explicit fix recipes are applied, against exact hashes.
Generated upstream source remains ignored under work/server-fixes.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT=Path(__file__).resolve().parents[1]


def prepare(verify_only=False):
    server=ROOT/'Server/ModernUO'
    pin=json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(server),'rev-parse','HEAD'],text=True).strip()==pin
    recipe=json.loads((ROOT/'Server/fixes/ethics-registry.json').read_text())
    local_path=ROOT/'work/server-fixes/approved-local-recipes.json'
    local=json.loads(local_path.read_text(encoding='utf-8')) if local_path.exists() else {}
    if local:
        assert local.get('approval_reference') and local.get('upstream_revision')==pin,'Local overlays need explicit approval and the exact dependency pin'
    local_entries=local.get('recipes',[])
    entries=[recipe]+recipe.get('additional_files',[])+local_entries
    assert len({Path(entry['path']).name for entry in entries})==len(entries),'Overlay output names must be unique'
    output=ROOT/'work/server-fixes';overlays=[]
    for entry in entries:
        source=server/entry['path'];raw=source.read_bytes()
        assert source.resolve().is_relative_to(server.resolve()),'Overlay source must remain inside the pinned checkout'
        text=raw.decode('utf-8-sig').replace('\r\n','\n')
        assert hashlib.sha256(text.encode('utf-8')).hexdigest()==entry['canonical_source_sha256'],'Server source changed; review the overlay against the new source before building'
        for change in entry['replacements']:
            assert text.count(change['before'])==1,'Fix anchor is missing or ambiguous'
            text=text.replace(change['before'],change['after'],1)
        generated=text.encode('utf-8')
        overlays.append({'source_path':entry['path'],'source_sha256':hashlib.sha256(raw).hexdigest(),'canonical_source_sha256':entry['canonical_source_sha256'],'overlay_sha256':hashlib.sha256(generated).hexdigest()})
        if not verify_only:
            output.mkdir(parents=True,exist_ok=True);path=output/source.name
            if not path.exists() or path.read_bytes()!=generated:path.write_bytes(generated)
    report={'upstream_revision':pin,'overlays':overlays,
            'recipe_sha256':hashlib.sha256((ROOT/'Server/fixes/ethics-registry.json').read_bytes()).hexdigest(),
            'local_recipe_sha256':hashlib.sha256(local_path.read_bytes()).hexdigest() if local_path.exists() else None,
            'scope':'Reviewed baseline and explicitly approved private build overlays; unchanged original checkout. Individual approved recipes define their gameplay/save scope.'}
    signature={'pin':pin,'base':report['recipe_sha256'],'local':report['local_recipe_sha256'],
               'preparer':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'targets':hashlib.sha256((ROOT/'Server/fixes/EthicsRegistry.targets').read_bytes()).hexdigest(),
               'builder':hashlib.sha256((ROOT/'scripts/build-server.ps1').read_bytes()).hexdigest(),
               'workspace':str(ROOT.resolve()),
               'overlays':[{key:row[key] for key in ['source_path','canonical_source_sha256','overlay_sha256']} for row in overlays]}
    report['input_signature']=hashlib.sha256(json.dumps(signature,sort_keys=True).encode()).hexdigest()
    if not verify_only:
        items=[]
        for entry in local_entries:
            path=entry['path'];assert path.startswith('Projects/UOContent/'),'Private content overlays must not modify the server engine'
            relative=escape(str(Path(path.removeprefix('Projects/UOContent/'))),{'"':'&quot;'})
            generated=escape((output/Path(path).name).as_posix(),{'"':'&quot;'})
            items.append(f'<Compile Remove="{relative}"/><Compile Include="{generated}" Link="{relative}"/>')
        targets='<Project><Target Name="BritanniaApprovedLocalContent" BeforeTargets="CoreCompile" Condition="\'$(MSBuildProjectName)\' == \'UOContent\'"><ItemGroup>'+''.join(items)+'</ItemGroup></Target></Project>'
        (output/'LocalFixes.targets').write_text(targets,encoding='utf-8')
        (output/'source-manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');parser.add_argument('--check-build',action='store_true');args=parser.parse_args()
    result=prepare(args.verify_only or args.check_build)
    if args.check_build:
        try:
            receipt=json.loads((ROOT/'work/server-fixes/build-manifest.json').read_text(encoding='utf-8-sig'))
            assembly=ROOT/'Server/ModernUO/Distribution/Assemblies/UOContent.dll'
            valid=receipt.get('input_signature')==result['input_signature'] and hashlib.sha256(assembly.read_bytes()).hexdigest()==receipt.get('assembly_sha256')
        except (OSError,ValueError):valid=False
        print('SERVER BUILD RECEIPT:', 'current' if valid else 'rebuild required')
        sys.exit(0 if valid else 2)
    print('SERVER FIX OVERLAY:',len(result['overlays']),'reviewed files / pinned source intact')
