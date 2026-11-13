"""Branch-aware band artifact and explicit migration regressions; no material claims."""
from pathlib import Path
import copy
import importlib.util
import json
import sys
import tempfile
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from visualization.band_adapters import _path_contract, BandDataset, band_node_ticks, validate_shared_path, load_dataset
from visualization.common import VisualizationError
from visualization.style import tex_text


class BandBranchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        self.kpoints = np.array([[0, 0, 0], [.25, 0, 0], [.5, 0, 0], [0, .1, 0], [0, .3, 0], [0, .5, 0]])
        self.payload = dict(schema='wanniernlqg.kpath', schema_version='2.0', total_kpoints=6,
            distance_unit='A^-1', lattice_convention='row-lattice', reciprocal_lattice_convention='B=2pi*A^(-T)',
            shared_segment_endpoints_written_once=True, fractional_coordinates_folded=False,
            node_chain=[dict(label=label, point_index_one_based=index + 1,
                cumulative_distance_A_inverse=distance, fractional_coordinates=self.kpoints[index].tolist())
                for label, index, distance in [('G', 0, 0), ('U', 2, 1), ('K', 3, 1), ('G', 5, 2)]],
            segments=[dict(segment_index_one_based=number, start_node_index_one_based=first,
                end_node_index_one_based=first + 1, start_point_index_one_based=start,
                end_point_index_one_based=stop, kpoints_including_endpoints=3)
                for number, first, start, stop in [(1, 1, 1, 3), (2, 3, 4, 6)]],
            connected_branches=[dict(start_point_index_one_based=1, end_point_index_one_based=3),
                                dict(start_point_index_one_based=4, end_point_index_one_based=6)])

    def parse(self, value):
        path = self.directory / 'path.json'
        path.write_text(json.dumps(value))
        return _path_contract(path, 6, self.kpoints)

    def test_actual_branch_endpoints_and_shared_distance(self):
        locations, indices, labels, _, _ = self.parse(self.payload)
        np.testing.assert_array_equal(indices, [0, 2, 3, 5])
        np.testing.assert_array_equal(locations, [0, 1, 1, 2])
        dataset = BandDataset('x', 'x', 'wanniernlqg', np.array([0, .5, 1, 1, 1.5, 2]),
            self.kpoints, np.ones((6, 2)), locations, labels, 0, True, 'ENGINEERING', (),
            connected_branches=((0, 3), (3, 6)))
        ticks, names = band_node_ticks(dataset)
        np.testing.assert_array_equal(ticks, [0, 1, 2])
        self.assertEqual(names, ('G', 'U|K', 'G'))
        altered = copy.copy(dataset)
        object.__setattr__(altered, 'connected_branches', ((0, 6),))
        with self.assertRaisesRegex(VisualizationError, 'connected branches'):
            validate_shared_path(dataset, altered)

    def test_catalogue_unicode_labels_have_explicit_tex_spelling(self):
        self.assertEqual(tex_text("H₀|Σ₂"), r"\textnormal{H\textsubscript{0}|\textSigma\textsubscript{2}}")

    def test_native_vasp_and_table_keep_declared_branches_and_raw_arrays(self):
        fixtures = ROOT / 'test/visualization/fixtures'
        config = json.loads((fixtures / 'vasp_native_compare.json').read_text())
        def resolve(value):
            result = dict(value)
            for key in ('eigenval', 'kpoints', 'poscar', 'data', 'path'):
                if key in result:
                    result[key] = str(fixtures / result[key])
            return result
        reference = load_dataset(resolve(config['reference']))
        table_spec = resolve(config['models'][0])
        table = load_dataset(table_spec)
        self.assertEqual(table.connected_branches, ((0, 2), (2, 4)))
        self.assertEqual(reference.connected_branches, table.connected_branches)
        np.testing.assert_array_equal(reference.energies_ev, table.energies_ev)
        np.testing.assert_array_equal(reference.fractional_kpoints, table.fractional_kpoints)
        np.testing.assert_array_equal(reference.distance, table.distance)
        validate_shared_path(reference, table)
        old = load_dataset(dict(table_spec, path=str(fixtures / 'vasp_path.json')))
        np.testing.assert_array_equal(old.energies_ev, table.energies_ev)
        with self.assertRaisesRegex(VisualizationError, 'connected branches differ'):
            validate_shared_path(reference, old)
        payload = json.loads((fixtures / 'vasp_branch_path.json').read_text())
        payload.pop('energy_reference_ev')
        path = self.directory / 'missing-reference.json'
        path.write_text(json.dumps(payload))
        with self.assertRaisesRegex(VisualizationError, 'finite energy_reference_ev'):
            load_dataset(dict(table_spec, path=str(path)))
        for name, mutate in (
            ('short-coordinates', lambda p: p['fractional_kpoints'].pop()),
            ('distance-shape', lambda p: p.update(distances_A_inverse=[0.0])),
            ('decreasing-distance', lambda p: p['distances_A_inverse'].__setitem__(2, -1.0)),
            ('node-distance', lambda p: p['node_chain'][1].update(cumulative_distance_A_inverse=0.5)),
        ):
            payload = json.loads((fixtures / 'vasp_branch_path.json').read_text())
            mutate(payload)
            path = self.directory / (name + '.json')
            path.write_text(json.dumps(payload))
            with self.assertRaises(VisualizationError):
                load_dataset(dict(table_spec, path=str(path)))

    def test_cross_branch_segment_rejected(self):
        value = copy.deepcopy(self.payload)
        value['segments'][1].update(start_node_index_one_based=2, end_node_index_one_based=3)
        with self.assertRaisesRegex(VisualizationError, 'crosses disconnected'):
            self.parse(value)

    def test_missing_branch_and_changed_coordinates_rejected(self):
        value = copy.deepcopy(self.payload)
        value['connected_branches'][1]['start_point_index_one_based'] = 5
        with self.assertRaises(VisualizationError):
            self.parse(value)
        value = copy.deepcopy(self.payload)
        value['node_chain'][2]['fractional_coordinates'][1] += .1
        with self.assertRaisesRegex(VisualizationError, 'coordinates disagree'):
            self.parse(value)

    def test_old_schema_requires_explicit_conversion_and_preserves_source(self):
        value = json.loads((ROOT / 'test/visualization/fixtures/band_path.json').read_text())
        value['schema_version'] = '1.0'
        value.pop('connected_branches')
        source, destination = self.directory / 'old.json', self.directory / 'new.json'
        source.write_text(json.dumps(value))
        original = source.read_bytes()
        with self.assertRaisesRegex(VisualizationError, 'explicitly migrate'):
            _path_contract(source, 3, np.array([[0, 0, 0], [.25, 0, 0], [.5, 0, 0]]))
        spec = importlib.util.spec_from_file_location('migration', ROOT / 'scripts/migrate_kpath.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        result = module.migrate(source, destination)
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual(result['node_chain'], value['node_chain'])
        self.assertEqual(result['segments'], value['segments'])
        with self.assertRaises(ValueError):
            module.migrate(source, source)
        with self.assertRaises(ValueError):
            module.migrate(source, destination)


if __name__ == '__main__':
    unittest.main()
