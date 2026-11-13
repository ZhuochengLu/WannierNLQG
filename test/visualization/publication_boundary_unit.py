"""Portable preview-binding and ordinary-exception publication regressions."""
from pathlib import Path
import argparse, copy, json, os, shutil, sys, unittest
from unittest.mock import patch

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from visualization import common as c, pdf_validation as v
from visualization.style import apply_style, resolve_style
from PIL import Image

v.verify_dependency_lock()
apply_style(resolve_style({'figsize': [3.2, 2.4], 'dpi': 180}))
figure = plt.figure(figsize=(3.2, 2.4))
axis = figure.add_axes([.22, .22, .65, .55])
axis.plot([-1, 1], [-1, 1]); axis.axhline(0, linestyle='--')
axis.set_xlabel(r'$k\;[\mathrm{\AA^{-1}}]$')
figure.text(.84, .9, r'$-$', fontsize=18, ha='center', va='center')
c.save_figure_atomic(figure, out/'fixture', 180, ['pdf', 'png'])
plt.close(figure)
cases = []

class FrozenFigure:
    def savefig(self, path, **kwargs):
        shutil.copyfile(out/('fixture.'+kwargs['format']), path)

def seal(stem):
    return c.seal_plot_sidecar(stem, plot_kind='focused_fixture', script_path=Path(__file__),
        inputs=[], outputs=[stem.with_suffix('.pdf'), stem.with_suffix('.png')],
        resolved_config={}, datasets=[], transforms=[], comparisons=[])

def change_preview(path):
    image = Image.open(path).convert('RGB')
    image.putpixel((0, 0), (37, 83, 149))
    image.save(path)

class BoundaryTests(unittest.TestCase):
    def test_repeat_identical_pdf_retains_fresh_renderer_records(self):
        stem = out/'repeated'
        c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
        first = json.loads(stem.with_suffix('.pdf.qa.json').read_text())
        actual_render = v.render_pdf_previews
        def changed_output(*arguments, **keywords):
            records = actual_render(*arguments, **keywords)
            change_preview(records['poppler']['preview']['path'])
            records['poppler']['preview'] = v.file_identity(records['poppler']['preview']['path'])
            records['poppler']['binding_sha256'] = v.readback_binding(records['poppler'])
            return records
        with patch.object(v, 'render_pdf_previews', changed_output):
            c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
        second = json.loads(stem.with_suffix('.pdf.qa.json').read_text())
        self.assertEqual(first['pdf']['sha256'], second['pdf']['sha256'])
        for renderer in ['poppler', 'ghostscript']:
            self.assertNotEqual(first['renderers'][renderer]['preview']['path'],
                                second['renderers'][renderer]['preview']['path'])
        self.assertNotEqual(first['renderers']['poppler']['preview']['sha256'],
                            second['renderers']['poppler']['preview']['sha256'])
        v.validate_readback_records(stem.with_suffix('.pdf'), second['renderers'])
        seal(stem)
        cases.append('Repeated identical PDF with different renderer bytes uses a fresh actual proof; no old preview reuse')

    def test_renderer_bytes_changed_without_hash_are_rejected(self):
        stem = out/'stale-at-export'
        for suffix in ['.pdf', '.png', '.pdf.qa.json']:
            shutil.copyfile((out/'fixture').with_suffix(suffix), stem.with_suffix(suffix))
        before = {suffix: c.sha256_file(stem.with_suffix(suffix)) for suffix in ['.pdf', '.png', '.pdf.qa.json']}
        actual_render = v.render_pdf_previews
        def stale_record(*arguments, **keywords):
            records = actual_render(*arguments, **keywords)
            change_preview(records['ghostscript']['preview']['path'])
            return records
        with patch.object(v, 'render_pdf_previews', stale_record):
            with self.assertRaisesRegex(c.VisualizationError, 'actual preview identity mismatch'):
                c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
        self.assertEqual(before, {suffix: c.sha256_file(stem.with_suffix(suffix)) for suffix in before})
        cases.append('Changed actual renderer bytes with stale hash reject before primary publication')

    def test_seal_rejects_preview_config_or_version_drift(self):
        for field in ['preview', 'configuration', 'version']:
            with self.subTest(field=field):
                stem = out/('seal-drift-'+field)
                c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
                proof_path = stem.with_suffix('.pdf.qa.json')
                proof = json.loads(proof_path.read_text())
                record = proof['renderers']['poppler']
                if field == 'preview':
                    change_preview(record['preview']['path'])
                elif field == 'configuration':
                    record['configuration']['dpi'] += 1
                    proof_path.write_text(json.dumps(proof))
                else:
                    record['version']['text'] = 'different renderer version'
                    proof_path.write_text(json.dumps(proof))
                with self.assertRaisesRegex(c.VisualizationError, 'PDF readback identity mismatch'):
                    seal(stem)
                self.assertFalse(stem.with_suffix('.plot.json').exists())
                cases.append('Seal rejects '+field+' drift')

    def transaction_fixture(self, name, existing=True):
        directory = out/name; directory.mkdir()
        staging = directory/'staging'; staging.mkdir()
        items = []
        for suffix in ['pdf', 'png', 'pdf.qa.json']:
            destination = directory/('main.'+suffix)
            source = staging/('new.'+suffix)
            source.write_bytes(('new '+suffix).encode())
            if existing:
                destination.write_bytes(('previous '+suffix).encode())
            items.append((source, destination))
        return staging, items

    def test_each_publish_stage_failure_before_and_after_replace_rolls_back(self):
        original_replace = os.replace
        for existing in [True, False]:
            for stage in range(3):
                for timing in ['before', 'after']:
                    with self.subTest(existing=existing, stage=stage, timing=timing):
                        staging, items = self.transaction_fixture(f'transaction-{existing}-{stage}-{timing}', existing)
                        baseline = {dest: dest.read_bytes() if dest.exists() else None for _, dest in items}
                        target = items[stage][1]; triggered = False
                        def injected(source, destination):
                            nonlocal triggered
                            if Path(source).parent == staging and Path(destination) == target and not triggered:
                                triggered = True
                                if timing == 'after':
                                    original_replace(source, destination)
                                raise OSError('injected '+timing+' publication failure')
                            return original_replace(source, destination)
                        with patch.object(c.os, 'replace', injected):
                            with self.assertRaisesRegex(c.VisualizationError, 'rollback verified; primary unchanged') as caught:
                                c._publish_output_set(items, staging)
                        self.assertEqual(caught.exception.publication_state['status'], 'ROLLED_BACK')
                        self.assertEqual(caught.exception.publication_state['remaining_changed'], [])
                        self.assertEqual(baseline, {dest: dest.read_bytes() if dest.exists() else None for _, dest in items})
                        cases.append(f'Rollback old_exists={existing}, stage={stage}, failure={timing}')

    def test_backup_failure_does_not_start_publication(self):
        staging, items = self.transaction_fixture('backup-failure')
        baseline = {dest: dest.read_bytes() for _, dest in items}
        with patch.object(c.shutil, 'copy2', side_effect=OSError('injected backup failure')):
            with self.assertRaisesRegex(c.VisualizationError, 'primary unchanged') as caught:
                c._publish_output_set(items, staging)
        self.assertEqual(caught.exception.publication_state['changed_before_rollback'], [])
        self.assertEqual(baseline, {dest: dest.read_bytes() for _, dest in items})
        cases.append('Backup failure preserves all old outputs')

    def test_failed_rollback_reports_exact_remaining_changed_path(self):
        staging, items = self.transaction_fixture('rollback-failure')
        original_replace = os.replace
        target = items[0][1]
        def injected(source, destination):
            if Path(destination) == target:
                if Path(source).parent == staging:
                    original_replace(source, destination)
                    raise OSError('injected post-replace failure')
                if Path(source).parent.name == 'publication-backup':
                    raise OSError('injected restore failure')
            return original_replace(source, destination)
        with patch.object(c.os, 'replace', injected):
            with self.assertRaisesRegex(c.VisualizationError, 'partial publication failure') as caught:
                c._publish_output_set(items, staging)
        state = caught.exception.publication_state
        self.assertNotIn('primary unchanged', str(caught.exception))
        self.assertEqual(state['remaining_changed'], [str(target)])
        self.assertEqual(target.read_bytes(), b'new pdf')
        self.assertEqual(items[1][1].read_bytes(), b'previous png')
        self.assertEqual(items[2][1].read_bytes(), b'previous pdf.qa.json')
        cases.append('Failed rollback reports exactly the changed PDF and never claims unchanged')

    def test_save_failure_preserves_accurate_partial_state_in_diagnostics(self):
        stem = out/'save-partial'
        c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
        # Force distinguishable current bytes so a post-replace failure is visible.
        stem.with_suffix('.pdf').write_bytes(b'previous primary PDF bytes')
        previous_png = stem.with_suffix('.png').read_bytes()
        previous_proof = stem.with_suffix('.pdf.qa.json').read_bytes()
        original_replace = os.replace
        target = stem.with_suffix('.pdf')
        def injected(source, destination):
            if Path(destination) == target:
                if Path(source).parent.name.startswith('.wanniernlqg-plot-'):
                    original_replace(source, destination)
                    raise OSError('injected save post-replace failure')
                if Path(source).parent.name == 'publication-backup':
                    raise OSError('injected save restore failure')
            return original_replace(source, destination)
        with patch.object(c.os, 'replace', injected):
            with self.assertRaisesRegex(c.VisualizationError, 'partial publication failure') as caught:
                c.save_figure_atomic(FrozenFigure(), stem, 180, ['pdf', 'png'])
        self.assertNotIn('primary unchanged', str(caught.exception))
        self.assertEqual(caught.exception.publication_state['remaining_changed'], [str(target)])
        self.assertEqual(stem.with_suffix('.png').read_bytes(), previous_png)
        self.assertEqual(stem.with_suffix('.pdf.qa.json').read_bytes(), previous_proof)
        diagnostic = list((out/'diagnostics/save-partial').rglob('publication-failure.json'))
        self.assertEqual(len(diagnostic), 1)
        self.assertEqual(json.loads(diagnostic[0].read_text())['remaining_changed'], [str(target)])
        cases.append('Actual save API retains accurate partial-publication diagnostics')

result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(BoundaryTests))
record = {'status': 'PASS' if result.wasSuccessful() else 'FAIL', 'tests': result.testsRun,
          'failures': len(result.failures), 'errors': len(result.errors), 'cases': cases,
          'case_count': len(cases), 'execution': v.execution_identity(),
          'scientific_qualification': 'NOT_EVALUATED',
          'scope': 'Actual preview/config/version binding, repeat export, publication backup/each rename/rollback failure'}
(out/'boundary-result.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps({'status': record['status'], 'tests': result.testsRun, 'case_count': len(cases)}))
raise SystemExit(0 if result.wasSuccessful() else 1)
