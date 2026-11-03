"""Synthetic frequency checks; no game data or running server required."""
import importlib.util, json, tempfile, unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('priority', Path(__file__).with_name('build-creature-priority.py'))
priority = importlib.util.module_from_spec(spec)
spec.loader.exec_module(priority)

class FrequencyTests(unittest.TestCase):
    def test_reviewed_mage_branch_uses_native_expansion_semantics(self):
        with tempfile.TemporaryDirectory(dir=priority.ROOT / 'work', prefix='creature-identity-') as folder:
            source = Path(folder)
            core = source / 'Projects/Server/Main.cs'
            enums = core.with_name('ExpansionInfo.cs')
            core.parent.mkdir(parents=True)
            core.write_text('public static bool UOR => Expansion >= Expansion.UOR;')
            enums.write_text('public enum Expansion { None, T2A, UOR, EJ }')
            constructor = source / 'Mage.cs'
            constructor.write_text('reviewed synthetic constructor')
            pins = {'native_sources': [{'class': 'Mage', 'path': 'Mage.cs', 'sha256': priority.sha(constructor), 'bodies': [125, 126]}]}
            with patch.object(priority, 'read', return_value=pins):
                # Feature flags do not override Core's expansion comparison.
                current, inputs = priority.configured_mage_identities(source, {'Id': 3, 'SupportedFeatures': {'UOR': False}})
                self.assertEqual(current, {'mage': {125, 126}})
                self.assertEqual(len(inputs), 3)
                self.assertEqual(priority.configured_mage_identities(source, {'Id': 1})[0], {'mage': {400}})
                constructor.write_text('changed constructor')
                with self.assertRaisesRegex(AssertionError, 'constructor changed'):
                    priority.configured_mage_identities(source, {'Id': 3})

    def test_random_constructor_witnesses_keep_other_era_branches(self):
        bodies, human = priority.identity_candidates({400}, {125, 126})
        self.assertEqual(bodies, {125, 126, 400})
        self.assertFalse(human)
        # Sampling just one variant is positive evidence, not a complete census.
        self.assertEqual(priority.identity_candidates({400}, {125}), ({125, 400}, False))
        self.assertEqual(priority.identity_candidates({400, 401}, {400}), ({400, 401}, True))
        self.assertEqual(priority.identity_candidates({0x25d, 0x25e}, set()), ({0x25d, 0x25e}, True))
        self.assertEqual(priority.identity_candidates({0x25d}, {125}), ({0x25d, 125}, False))

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
