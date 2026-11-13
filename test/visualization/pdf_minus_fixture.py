"""Real TeX vector A/B; the old environment must fail and the fixed one pass."""
from pathlib import Path
import argparse,importlib.util,json,sys
parser=argparse.ArgumentParser()
parser.add_argument('--source-root',type=Path,required=True)
parser.add_argument('--validator',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--expected-version',required=True)
parser.add_argument('--expect-missing-minus',action='store_true')
c=parser.parse_args();c.output.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(c.source_root/'scripts'))
from visualization.style import apply_style,resolve_style
from visualization.common import save_figure_atomic
import matplotlib,matplotlib.pyplot as plt
assert matplotlib.__version__==c.expected_version
apply_style(resolve_style({'figsize':[6.4,5.4],'dpi':180}))
fig=plt.figure(figsize=(6.4,5.4))
labels=[r'$-1$',r'$1$',r'$\mathrm{\AA^{-1}}$',r'$10^{-3}$',r'$(-5,+5)$',r'$\pm1$',r'$\mathrm{eV^{-1}}$',r'$E-E_{\mathrm{VBM}}$']
for index,label in enumerate(labels):
 fig.text(.22+.40*(index%2),.82-.085*(index//2),label,ha='center',va='center',fontsize=18)
center=(.87,.9)
fig.text(*center,r'$-$',ha='center',va='center',fontsize=18)
ax=fig.add_axes([.13,.13,.75,.32]);ax.plot([-1,1],[-1,1]);ax.axhline(0,linestyle='--');ax.set_xticks([-1,0,1]);ax.set_yticks([-1,0,1]);ax.set_xlabel(r'$k\;\mathrm{(\AA^{-1})}$');ax.set_ylabel(r'$E\;\mathrm{(eV)}$')
outputs=save_figure_atomic(fig,c.output/'minus-fixture',180,['pdf','png']);plt.close(fig)
spec=importlib.util.spec_from_file_location('pdf_validation_audit',c.validator);v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
pdf=c.output/'minus-fixture.pdf';png=c.output/'minus-fixture.png'
renderers=v.render_pdf_previews(pdf,c.output/'readback',180)
if c.expect_missing_minus:
 try:v.validate_native_pdf(pdf)
 except v.PDFValidationError as error:
  expected=str(error)
  assert "code 0" in expected,expected
 else:raise RuntimeError('Old A unexpectedly passed native glyph validation')
 from PIL import Image
 import numpy as np
 def count(path):
  rgb=np.asarray(Image.open(path).convert('RGB'));h,w=rgb.shape[:2];x,y=center
  cx,cy=x*w,(1-y)*h;box=(round(cx-22.5),round(cy-16.2),round(cx+22.5),round(cy+16.2))
  tile=rgb[box[1]:box[3],box[0]:box[2]];Image.fromarray(tile).save(c.output/(Path(path).stem+'-old-minus-roi.png'))
  return int(np.any(tile<230,axis=2).sum())
 counts={'reference_png':count(png),**{name:count(row['preview']['path']) for name,row in renderers.items()}}
 assert counts['reference_png']>=8 and counts['poppler']==0 and counts['ghostscript']==0,counts
 result={'status':'EXPECTED_OLD_ENVIRONMENT_FAILURE_REPRODUCED','version':matplotlib.__version__,'error':expected,'isolated_math_minus_ink_pixels':counts,'execution':v.execution_identity(),'renderers':renderers}
else:
 result=v.validate_minus_probe(pdf,png,c.output/'probe',center,180)
 result['version']=matplotlib.__version__
(c.output/'fixture-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'version':matplotlib.__version__,'output':str(c.output)}))
