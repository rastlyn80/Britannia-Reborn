"""Synthetic frequency checks; no game data or running server required."""
import importlib.util, json, tempfile, unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('priority', Path(__file__).with_name('build-creature-priority.py'))
priority = importlib.util.module_from_spec(spec)
spec.loader.exec_module(priority)

class FrequencyTests(unittest.TestCase):
    def test_mixed_constructor_needs_its_own_specialized_human_witnesses(self):
        bodies={14,51,400,401};routed={14:'earth',51:'slime'}
        self.assertEqual(priority.missing_routes(bodies,routed,set()),{400,401})
        self.assertEqual(priority.missing_routes(bodies,routed,{400}),{401})
        self.assertEqual(priority.missing_routes(bodies,routed,bodies),set())
        # A positive native nonhuman witness cannot manufacture a model route.
        self.assertEqual(priority.missing_routes(bodies,{14:'earth'},bodies),{51})

    def test_shared_capacity_is_not_multiplied_per_species(self):
        self.assertEqual(priority.allocate(8, [{'name': n, 'maxCount': 8} for n in ['bird', 'rat', 'cat', 'orc']]), [2., 2., 2., 2.])

    def test_probability_caps_and_disabled_entries(self):
        entries = [{'probability': 3, 'maxCount': 1}, {'probability': 1, 'maxCount': 10}, {'probability': 0, 'maxCount': 100}]
        self.assertEqual(priority.allocate(5, entries), [1., 4., 0.])
        self.assertEqual(priority.allocate(50, entries), [1., 10., 0.])
        self.assertEqual(priority.allocate(0, entries), [0., 0., 0.])

    def test_era_map_duplicate_and_item_competition(self):
        with tempfile.TemporaryDirectory(dir=priority.ROOT / 'work', prefix='creature-frequency-') as folder:
            root = Path(folder)
            self.assertTrue(root.resolve().is_relative_to((priority.ROOT / 'work').resolve()))
            for group in ['shared', 'post-uoml', 'uoml']:
                path = root / group / 'trammel' / 'test.json'
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps([{'guid': group, 'map': 'Trammel', 'count': 4,
                    'entries': [{'name': 'Bird', 'maxCount': 4}, {'name': 'Gold', 'maxCount': 4}]}]))
            files = priority.source_files(root, 'post-uoml', {'trammel'})
            self.assertEqual(len(files), 2)
            rows, count = priority.occurrences(files, {'trammel'})
            self.assertEqual(count, 2)
            self.assertEqual(rows['bird']['estimated_slots'], 4.)
            self.assertEqual(rows['bird']['spawn_locations'], 2)
            self.assertEqual(rows['gold']['estimated_slots'], 4.)
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                priority.occurrences(files + files, {'trammel'})
            self.assertEqual(priority.occurrences(files, {'felucca'}), ({}, 0))

    def test_inheritance_and_source_graph(self):
        classes = {'bird': {'base': 'BaseCreature'}, 'basecreature': {'base': 'Mobile'}, 'mobile': {'base': None}}
        self.assertEqual(priority.ancestors('Bird', classes), ['bird', 'basecreature', 'mobile'])
        classes['mobile']['base'] = 'Bird'
        self.assertEqual(len(priority.ancestors('Bird', classes)), 3)

if __name__ == '__main__':
    unittest.main()
