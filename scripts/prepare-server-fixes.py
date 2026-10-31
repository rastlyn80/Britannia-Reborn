"""Create reviewed build-only overlays without modifying the pinned checkout.

Only the repository's explicit fix recipes are applied, against exact hashes.
Generated upstream source remains ignored under work/server-fixes.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def prepare(verify_only=False):
    server=ROOT/'Server/ModernUO'
    pin=json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(server),'rev-parse','HEAD'],text=True).strip()==pin
    recipe=json.loads((ROOT/'Server/fixes/ethics-registry.json').read_text())
    output=ROOT/'work/server-fixes';overlays=[]
    for entry in [recipe]+recipe.get('additional_files',[]):
        source=server/entry['path'];raw=source.read_bytes()
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
            'scope':'Native ethics registry, enabled-world bootstrap and player restoration; unchanged save schema and original checkout'}
    if not verify_only:
        (output/'source-manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true')
    result=prepare(parser.parse_args().verify_only)
    print('SERVER FIX OVERLAY:',len(result['overlays']),'reviewed files / pinned source intact')
