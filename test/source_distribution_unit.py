"""Exercise export boundaries without Julia, launchers, numerical work or source edits."""
import importlib.util
import json
import tomllib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('distribution', ROOT / 'scripts/export_public_source.py')
distribution = importlib.util.module_from_spec(spec)
spec.loader.exec_module(distribution)


class DistributionBoundaryTests(unittest.TestCase):
    def policy(self):
        return dict(schema='wanniernlqg.source-distribution/1', features={
            'core': dict(public=True, paths=['core.jl', 'both.jl']),
            'future-private': dict(public=False, paths=['private.jl', 'both.jl'])})

    def test_projected_fixture_hashes_bind_actual_public_bytes(self):
        data = b'public helper\n'
        prefix = 'test/fixtures/first_use_portable/'
        manifest = dict(files=[dict(file='helper.jl', bytes=len(data), sha256=distribution.sha(data))])
        payload = {prefix+'manifest.json': json.dumps(manifest).encode(), prefix+'helper.jl': data}
        distribution.audit_fixture_manifests(payload)
        payload[prefix+'helper.jl'] = b'changed helper\n'
        with self.assertRaisesRegex(ValueError, 'projected fixture binding mismatch'):
            distribution.audit_fixture_manifests(payload)

    def test_projected_fixture_member_cannot_escape_or_disappear(self):
        prefix = 'test/fixtures/first_use_portable/'
        for name in ('../helper.jl', '/helper.jl', 'missing.jl'):
            payload = {prefix+'manifest.json': json.dumps(dict(files=[dict(file=name, bytes=0, sha256=distribution.sha(b''))])).encode()}
            with self.assertRaises(ValueError):
                distribution.audit_fixture_manifests(payload)

    def test_private_precedence(self):
        public, private = distribution.classify(
            {'core.jl': b'', 'private.jl': b'', 'both.jl': b''}, self.policy())
        self.assertEqual(public, {'core.jl'})
        self.assertEqual(private, {'private.jl', 'both.jl'})


    def test_new_path_and_missing_path_block(self):
        for payload in ({'core.jl': b'', 'private.jl': b'', 'both.jl': b'', 'new.jl': b''},
                        {'core.jl': b'', 'private.jl': b''}):
            with self.assertRaises(ValueError):
                distribution.classify(payload, self.policy())

    def test_truthy_status_rejects(self):
        policy = self.policy()
        policy['features']['future-private']['public'] = 'false'
        with self.assertRaisesRegex(ValueError, 'Boolean'):
            distribution.classify({'core.jl': b'', 'private.jl': b'', 'both.jl': b''}, policy)

    def test_declared_public_feature_dependency_on_private_blocks(self):
        policy = self.policy()
        policy['features']['core']['dependencies'] = ['future-private']
        with self.assertRaisesRegex(ValueError, 'depends on private feature'):
            distribution.classify({'core.jl': b'', 'private.jl': b'', 'both.jl': b''}, policy)

    def test_private_policy_output_cannot_be_readded(self):
        policy = dict(schema='wanniernlqg.source-distribution/1', features={
            'core': dict(public=True, paths=['scripts/source_distribution.json']),
            'future-private': dict(public=False, paths=['scripts/source_distribution.json'])})
        with self.assertRaisesRegex(ValueError, 'explicitly public'):
            distribution.project({'scripts/source_distribution.json': b'{}'}, policy)

    def test_public_private_dependency_block(self):
        for text in (b'include("private_driver.jl")', b'include("../private_driver.jl")', b'SecretKernel()'):
            with self.assertRaises(ValueError):
                distribution.audit_closure({'core.jl': text}, {'private_driver.jl'}, ['SecretKernel'])

    def test_private_python_imports_cannot_hide_behind_sys_path(self):
        for source in (b'import secret_runner\n', b'from secret_runner import run\n',
                       b'import importlib\nimportlib.import_module("secret_runner")\n'):
            with self.subTest(source=source), self.assertRaisesRegex(ValueError, 'private Python module'):
                distribution.audit_closure({'user.py': source}, {'private/secret_runner.py'}, [])
        distribution.audit_closure({'user.py': b'import common_profiles\n',
            'test_support/common_profiles.py': b''}, {'private/common_profiles.py'}, [])

    def test_markdown_links_cannot_retain_private_documents(self):
        for text in (b'See [hidden](PRIVATE.md)', b'See [hidden](../docs/PRIVATE.md#details)',
                     b'See [hidden](PRIVATE%2Emd)'):
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, 'links to denied file'):
                distribution.audit_closure({'docs/Guide.md': text}, {'docs/PRIVATE.md'}, [])
        distribution.audit_closure({'docs/Guide.md': b'See [public](PUBLIC.md#details)',
                                    'docs/PUBLIC.md': b'public'}, {'vendor/PUBLIC.md'}, [])

    def test_missing_literal_include_blocks(self):
        for text in (b'include("absent.jl")', b'include(joinpath(@__DIR__, "sub", "absent.jl"))'):
            with self.assertRaisesRegex(ValueError, 'unresolved public include'):
                distribution.audit_closure({'core.jl': text}, set(), [])

    def test_retained_document_path_does_not_reference_private_namesake(self):
        private_path = '/'.join(('vendor', 'ESKernel', 'docs/DEVELOPMENT.md'))
        denied = {private_path}
        payload = {'core.py': b"ALLOWED={'docs/DEVELOPMENT.md'}",
                   'docs/DEVELOPMENT.md': b'public documentation'}
        distribution.audit_closure(payload, denied, [])
        for reference in (private_path, Path(private_path).name):
            with self.assertRaisesRegex(ValueError, 'denied file'):
                distribution.audit_closure(dict(payload, **{'core.py': repr(reference).encode()}), denied, [])

    def test_generated_data_names_do_not_imply_private_fixture_dependencies(self):
        denied = {'private/fixture/synthetic_tb.dat', 'private/fixture/synthetic.WAVECAR'}
        for leaf in ('synthetic_tb.dat', 'synthetic.WAVECAR'):
            distribution.audit_closure({'current_test.jl': ('output = ' + repr(leaf)).encode()}, denied, [])
        for path in denied:
            with self.assertRaisesRegex(ValueError, 'denied file'):
                distribution.audit_closure({'current_test.jl': ('input = ' + repr(path)).encode()}, denied, [])

    def test_retained_relative_helper_does_not_reference_archived_namesake(self):
        private = {'archive/supports/SharedFixtureHelper.jl'}
        public = {'test/Probe.jl': b'include(joinpath(@__DIR__, "SharedFixtureHelper.jl"))',
                  'test/SharedFixtureHelper.jl': b'# public helper'}
        distribution.audit_closure(public, private, [])
        with self.assertRaises(ValueError):
            distribution.audit_closure({'test/Probe.jl': public['test/Probe.jl']}, private, [])
        with self.assertRaises(ValueError):
            distribution.audit_closure(dict(public, **{'test/Other.jl': b'include("archive/supports/SharedFixtureHelper.jl")'}), private, [])

    def test_ignored_bytes_are_commit_bound(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / '.gitignore').write_text('ignored.toml\n')
            (root / 'ignored.toml').write_text('original\n')
            subprocess.run(['git', 'init', '--quiet', str(root)], check=True)
            subprocess.run(['git', '-C', str(root), 'add', '-f', '.gitignore', 'ignored.toml'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Local test',
                '-c', 'user.email=local-test@localhost', 'commit', '--quiet', '-m', 'fixture'], check=True)
            commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
            distribution.verify_commit_payload(root, commit)
            (root / 'ignored.toml').write_text('changed\n')
            with self.assertRaises(ValueError):
                distribution.verify_commit_payload(root, commit)

    def test_reviewed_projection_rejects_drift(self):
        policy = dict(schema='wanniernlqg.source-distribution/1', features={
            'core': dict(public=True, paths=['core.jl', 'scripts/source_distribution.json']),
            'future-private': dict(public=False, paths=[], projections={
                'core.jl': [dict(internal='private-call', public='public-call')]})})
        source = {'core.jl': b'changed-call', 'scripts/source_distribution.json': b'{}'}
        with self.assertRaisesRegex(ValueError, 'attachment drift'):
            distribution.project(source, policy)

    def test_actual_policy_projects(self):
        policy = json.loads((ROOT / 'scripts/source_distribution.json').read_text())
        source = distribution.files(ROOT)
        public, private = distribution.project(source, policy)
        self.assertFalse(set(public) & private)
        public_gate = public['scripts/check_structure_boundaries.jl'].decode()
        self.assertIn('expected_negative_sawf_flat_reads = Set{String}()', public_gate)
        self.assertNotIn('ordinary_default.win_file', public_gate)
        self.assertIn('src/MatrixElements/NonorthogonalMatrixElements.jl', public)
        self.assertIn('src/MatrixElements/Interpolated/MixedFourierMatrixElements.jl', public)
        self.assertIn('src/FirstUse/RepresentativePublicWorkloads.jl', public)
        self.assertIn('MPI', json.loads(public['scripts/source_distribution.json'])['features']['public-core']['dependencies'])
        self.assertIn('test/support/CurrentScientificValues.jl', public)
        matrix = public['src/MatrixElements/MatrixElementsModule.jl'].decode()
        for leaf in ('OrthogonalGeometryDerivativePlan.jl', 'OrthogonalGeometryJets.jl'):
            self.assertIn('Interpolated/' + leaf, matrix)
        # The ordinary public replica-plan consumer shares this module import with
        # private CanonicalParentMap; removing the private feature must retain it.
        operator = public['ext/WannierNLQGWannierizationExt/components/OperatorExport.jl'].decode()
        self.assertIn('import WannierNLQG.MatrixElements\n', operator)
        construction = public['ext/WannierNLQGWannierizationExt/TightBindingConstruction.jl'].decode()
        self.assertIn('WannierNLQG.MatrixElements.wannier_pair_wigner_seitz_plan_from_images(', construction)
        contract = tomllib.loads(public['test/contracts/wannierization_components.toml'].decode())
        self.assertIs(contract['components']['OperatorExport']['imports']['WannierNLQG.MatrixElements']['module_binding'], True)
        inventory = public['test/CITestPlan.jl'].decode()
        for stem in ('orthogonal_geometry_analytic', 'berry_geometry_backend_runtime',
                     'berry_multipole_dc', 'berry_multipole_runtime', 'berry_geometry_fourier',
                     'berry_multipole_periodic', 'berry_multipole_dirac', 'berry_geometry_multiband'):
            self.assertIn('"' + stem + '_unit.jl"', inventory)
        self.assertIn(':berry_multipole', public['test/api_snapshot_unit.jl'].decode())
        self.assertIn('ForwardDiff', public['test/Project.toml'].decode())
        self.assertIn('julia_version = "1.13.0"', public['test/Manifest.toml'].decode())




    def test_public_snapshot_keeps_interleaved_ordinary_transition_exports(self):
        # This ordinary API declaration lies between private EPC declarations.
        # Exercise the actual export policy, including downstream formatting.
        policy = json.loads((ROOT / 'scripts/source_distribution.json').read_text())
        projected, _ = distribution.project(distribution.files(ROOT), policy)
        snapshot = projected['test/api_snapshot_unit.jl'].decode()
        name = 'RESPONSES_SHARED_TRANSITION_API_20261016'
        self.assertEqual(snapshot.count('const ' + name + ' = Set(['), 1)
        self.assertEqual(snapshot.count(name), 2)
        for export in ('photon_drag_transition_denominator_weight',
                       'photon_drag_weighted_occupations!',
                       'intrinsic_hall_fermi_sea'):
            self.assertIn(':' + export, snapshot)
        self.assertNotIn(':intrinsic_hall_occupation_blocks', snapshot)
        self.assertNotIn('EPC_RESPONSES_API_2_0', snapshot)
        self.assertNotIn('EPC_RUNTIME_API_2_0', snapshot)


    def test_public_interrupt_worker_keeps_generic_rejection_checks(self):
        policy = json.loads((ROOT / 'scripts/source_distribution.json').read_text())
        projected, _ = distribution.project(distribution.files(ROOT), policy)
        worker = projected['test/run_tests_unit.py'].decode()
        self.assertNotIn('LIFECYCLE_SELECTOR', worker)
        self.assertNotIn('class CIControlledGroupLifecycle', worker)
        self.assertIn('def test_interrupt_worker_rejects_unregistered_inputs_before_launch', worker)
        self.assertIn('alias.symlink_to(self.directory, target_is_directory=True)', worker)
        self.assertIn('self.julia.write_text(FAKE +', worker)


if __name__ == '__main__':
    unittest.main()
