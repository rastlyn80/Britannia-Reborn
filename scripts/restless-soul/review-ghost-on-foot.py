"""Measure and render the exact sampled candidate poses beside registered sprites."""

import json
from pathlib import Path
import runpy
from statistics import mean

from PIL import Image, ImageDraw, ImageOps

M = runpy.run_path(str(Path(__file__).with_name('compare-ghost-silhouettes.py')))
REVIEW = M['REVIEW']
T = M['T']
CLIPS = {
    6: ('GhostFidgetBreath', 'Idle'), 7: ('GhostReadyOneHand', 'Idle'),
    8: ('GhostReadyTwoHand', 'Idle'), 9: ('GhostFittedOneHand', 'GhostSlashOneHand'),
    12: ('GhostFittedDown', 'GhostBashTwoHand'), 13: ('GhostFittedWide', 'GhostSlashTwoHand'),
    14: ('GhostFittedJab', 'GhostPierceTwoHand'), 15: ('GhostWarWalk', 'Idle'),
    16: ('GhostDirectedBend', 'GhostCastDirected'), 17: ('GhostAreaReach', 'GhostCastArea'),
    18: ('GhostDrawBow', 'Idle'), 19: ('GhostFireCrossbow', 'Idle'),
    30: ('GhostTurnCheck', 'GhostTurn'), 31: ('GhostAdvanceStrike', 'Attack'),
    32: ('GhostLowerBow', 'GhostBow'), 33: ('GhostGreeting', 'GhostSalute'),
    34: ('GhostChestFidget', 'Idle'),
}


def compare(source, poses, camera):
    return [
        [M['silhouette'](poses[round(24 * i / max(1, len(source) - 1))], view, camera['scale'], camera['pitch'],
                         camera['yaw'], camera['sense'], camera['offsets'][view]) for view in range(5)]
        for i in range(len(source))]


def metrics(source, predicted):
    views = [[M['compare'](M['bits'](a), M['bits'](b)) for a, b in zip(s, p)]
             for s, p in zip(source, predicted)]
    return mean(mean(frame) for frame in views), min(mean(frame) for frame in views)


def main():
    camera = T['read'](REVIEW / 'restless-soul-silhouette-comparison.json')['camera']
    data = T['read'](REVIEW / 'ghost-on-foot-poses.json')['poses']
    baseline = T['read'](REVIEW / 'ghost-library-poses.json')['poses']
    sources = M['source_masks']()
    summaries = {}
    for group, slots in enumerate((list(CLIPS)[:8], list(CLIPS)[8:])):
        sheet = Image.new('RGB', (990, 90 * len(slots)), '#263742')
        draw = ImageDraw.Draw(sheet)
        for index, slot in enumerate(slots):
            label, old = CLIPS[slot]
            source = sources[slot]
            rendered = compare(source, data[label], camera)
            prior = compare(source, baseline[old], camera)
            current_metrics = metrics(source, rendered)
            baseline_metrics = metrics(source, prior)
            summaries[slot] = dict(clip=label, baseline=old, current=current_metrics, prior=baseline_metrics)
            print(slot, label, tuple(round(v, 3) for v in current_metrics),
                  old, tuple(round(v, 3) for v in baseline_metrics))
            draw.text((5, index * 90 + 7), str(slot), fill='white')
            for col, direction in enumerate((0, 2, 4)):
                for step, frame in enumerate((0, len(source) // 2, len(source) - 1)):
                    a, b = source[frame][direction], rendered[frame][direction]
                    difference = Image.merge('RGB', (a, b, b))
                    clipped = difference.crop((43, 50, 126, 136))
                    sheet.paste(clipped, (32 + col * 312 + step * 96, index * 90))
        sheet.save(REVIEW / f'ghost-on-foot-comparison-{group}.png')
    (REVIEW / 'ghost-on-foot-metrics.json').write_text(json.dumps(summaries, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
