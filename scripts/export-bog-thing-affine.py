"""Export Bog Thing's complete multipart skin with its original affine motions."""
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
SOURCE = runpy.run_path(str(SCRIPTS / 'prepare-bog-thing-source.py'))
AFFINE = runpy.run_path(str(SCRIPTS / 'export-gazer-larva-affine.py'))


def main():
    manifest = SOURCE['inputs']()
    tools = SOURCE['MIXED']['pipeline']()
    model, _ = SOURCE['decode'](manifest, tools)
    scale = round(manifest['authored_unit_factor'] * manifest['model_table_assignment']['scale'][0], 8)
    AFFINE['export_model'](model, tools.td, SOURCE['SOURCE'], SOURCE['WORK'] / 'owned-source',
                           SOURCE['MANIFEST'], stem='bog_thing', output='bog-thing-full-affine-dense.gltf',
                           scale=scale, node_name='OriginalBogThingAndPieces')


if __name__ == '__main__':
    main()
