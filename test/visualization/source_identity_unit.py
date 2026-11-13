"""Captured Runtime geometry and explicit historical metadata conversion contracts."""
from pathlib import Path
from dataclasses import replace
import json,sys,tempfile,unittest
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from visualization.kslice_parser import load_metadata,load_model_lattice
from visualization.common import VisualizationError
from migrate_kslice_metadata import convert_metadata
FIXTURES=ROOT/'test/visualization/fixtures'

class SourceIdentityTests(unittest.TestCase):
    def setUp(self):
        self.metadata=load_metadata(FIXTURES/'metadata_cart_orthogonal.txt')
    def test_identity_is_opaque_not_sha_authentication(self):
        local=replace(self.metadata,model_identity='wanniernlqg.file-state/1:(device = 1, inode = 2)')
        lattice=load_model_lattice(local)
        self.assertEqual(lattice.model_identity,local.model_identity)
        self.assertEqual(lattice.geometry_metadata_path,local.path)
        self.assertEqual(local.audit_record()['model_identity'],local.model_identity)
        self.assertEqual(lattice.manifest_record['identity_semantics'],'opaque provenance; not content authentication')
    def test_complete_orthogonal_and_skew_snapshots(self):
        lattice=load_model_lattice(self.metadata)
        np.testing.assert_array_equal(lattice.lattice_rows_angstrom,np.diag([2.,3.,4.]))
        np.testing.assert_array_equal(lattice.reciprocal_rows_inverse_angstrom,np.diag([np.pi,2*np.pi/3,np.pi/2]))
        skew=load_model_lattice(load_metadata(FIXTURES/'metadata_cart_skew.txt'))
        self.assertEqual(skew.lattice_rows_angstrom[1,0],.7)
        np.testing.assert_allclose(skew.lattice_rows_angstrom@skew.reciprocal_rows_inverse_angstrom.T,2*np.pi*np.eye(3),atol=1e-15)
    def test_model_override_cannot_replace_snapshot(self):
        with self.assertRaises(VisualizationError):load_model_lattice(self.metadata,str(FIXTURES/'skew_tb.dat'))
        local=replace(self.metadata,model_file='/does/not/exist',model_input_mode='native_nonorthogonal')
        np.testing.assert_array_equal(load_model_lattice(local).lattice_rows_angstrom,np.diag([2.,3.,4.]))
    def test_invalid_or_missing_geometry_rejected(self):
        for geometry in [{},{**self.metadata.geometry,'schema':'future/99'},{**self.metadata.geometry,'lattice_row.1_angstrom':'(0,0,0)'},{**self.metadata.geometry,'lattice_row.3_angstrom':'(NaN,0,1)'},{**self.metadata.geometry,'lattice_convention':'column'}]:
            with self.assertRaises((VisualizationError,ValueError)):load_model_lattice(replace(self.metadata,geometry=geometry))
    def test_explicit_conversion_preserves_original_and_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'old.txt';output=Path(tmp)/'new.txt'
            original=(FIXTURES/'metadata_cart_skew.txt').read_text()
            start=original.index('[Geometry]');end=original.index('[Numerics]',start)
            original=original[:start]+original[end:]
            source.write_text(original)
            before=source.read_bytes()
            result=convert_metadata(source,output,FIXTURES/'skew_tb.dat')
            self.assertEqual(source.read_bytes(),before)
            self.assertTrue(output.read_bytes().startswith(before))
            self.assertEqual(result['qualification'],'FORMAT_CONVERSION_ONLY')
            np.testing.assert_array_equal(load_model_lattice(load_metadata(output)).lattice_rows_angstrom,load_model_lattice(load_metadata(FIXTURES/'metadata_cart_skew.txt')).lattice_rows_angstrom)
            with self.assertRaises(VisualizationError):convert_metadata(source,output,FIXTURES/'skew_tb.dat')
    def test_conversion_rejects_unproven_or_wrong_historical_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'old.txt';output=Path(tmp)/'new.txt'
            original=(FIXTURES/'metadata_cart_orthogonal.txt').read_text()
            start=original.index('[Geometry]');end=original.index('[Numerics]',start)
            original=original[:start]+original[end:]
            source.write_text(original)
            with self.assertRaises(VisualizationError):convert_metadata(source,output,FIXTURES/'skew_tb.dat')
            source.write_text(original.replace(self.metadata.model_identity,'wanniernlqg.file-state/1:opaque'))
            with self.assertRaises(VisualizationError):convert_metadata(source,output,FIXTURES/'orthogonal_tb.dat')
            self.assertFalse(output.exists())

if __name__=='__main__':
    result=unittest.TextTestRunner(stream=sys.stderr,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(SourceIdentityTests))
    print(json.dumps(dict(source_root=str(ROOT),tests_run=result.testsRun,failures=len(result.failures),errors=len(result.errors),passed=result.wasSuccessful(),python=str(Path(sys.executable).resolve()),numpy_binary=str(Path(np._core._multiarray_umath.__file__).resolve()),numpy_version=np.__version__,numpy_file=str(Path(np.__file__).resolve()))))
    sys.exit(0 if result.wasSuccessful() else 1)
