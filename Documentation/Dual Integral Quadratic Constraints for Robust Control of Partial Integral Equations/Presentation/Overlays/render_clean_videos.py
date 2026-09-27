"""Render the existing cart motion and sector data without baked text, at 4K."""
from pathlib import Path
import sys,importlib.util,inspect,ast,subprocess,json
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/deck_label_overlays'
class ScaledDraw:
    def __init__(self,im,scale):self.draw=ImageDraw.Draw(im);self.scale=scale
    def __getattr__(self,name):
        if name=='text':return lambda *a,**kw:None
        def method(coords,*args,**kw):
            a=np.asarray(coords,dtype=float)*self.scale
            coords=[tuple(v) for v in a] if a.ndim==2 else tuple(a)
            if 'width' in kw:kw['width']=max(1,round(kw['width']*self.scale))
            return getattr(self.draw,name)(coords,*args,**kw)
        return method
def encode(path,frames,size,fps):
    cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',size,'-r',str(fps),'-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(path)]
    with subprocess.Popen(cmd,stdin=subprocess.PIPE) as p:
        for frame in frames:p.stdin.write(frame.tobytes())
        p.stdin.close();assert p.wait()==0
    print('Rendered '+path.name,flush=True)
def carts():
    spec=importlib.util.spec_from_file_location('cart',ROOT/'Figures/Cart/cart_flex_animation.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
    data=np.load(OUT/'cart_data.npz');c.DATA=data['data'];c.POSITION_SCALE=float(data['position_scale']);c.DEFLECTION_SCALE=float(data['deflection_scale']);c.EQUATIONS=None
    source=inspect.getsource(c.frame)
    tree=ast.parse(source)
    class StripLabels(ast.NodeTransformer):
        def visit_Expr(self,node):
            if isinstance(node.value,ast.Call) and isinstance(node.value.func,ast.Attribute) and node.value.func.attr=='text':return None
            return node
    tree=StripLabels().visit(tree);ast.fix_missing_locations(tree);source=ast.unparse(tree)
    source=source.replace("(W, H)","(W*4, H*4)").replace('d = ImageDraw.Draw(im)','d = ScaledDraw(im,4)')
    # Removing the sole text statement leaves an empty flexible-label branch.
    source=source.replace('if flexible:\n    for wheel','if flexible:\n        pass\n    for wheel')
    c.__dict__['ScaledDraw']=ScaledDraw
    exec(source,c.__dict__)
    positions={}
    for flexible,name in [(False,'rigid'),(True,'flexible')]:
        c.frame(0,flexible).save(OUT/('cart_'+name+'_clean.png'))
        encode(OUT/('cart_'+name+'_clean.mp4'),(c.frame(i,flexible) for i in range(300)),'3840x2160',30)
        base=480+c.POSITION_SCALE*(c.DATA[:300,0]-.075)
        tip=base+c.DEFLECTION_SCALE*(c.DATA[:300,2:5]@c.SHAPE[:,-1]) if flexible else base
        target=np.array([480+c.POSITION_SCALE*(c.command(i/30)-.075) for i in range(300)])
        positions[name]=dict(base=base.tolist(),tip=tip.tolist(),target=target.tolist())
    (OUT/'cart_label_positions.json').write_text(json.dumps(positions))
def sector():
    sys.path.insert(0,str(ROOT/'Presentation/SectorIQC'))
    import simulate_stn_gpe as s
    saved=np.load(s.OUT/'stn_gpe_sector_data.npz');data=tuple(saved[k] for k in ['t','x','z','w','q','integral'])
    import render_dissipativity as r
    source=inspect.getsource(r.render)
    source=source.replace("(1440,810)","(3840,2160)").replace('d=ImageDraw.Draw(im)','d=ScaledDraw(im,3840/1440)')
    # Axis titles, tick text, and legend text all become PowerPoint overlays.
    start=source.index('        font=ImageFont.truetype',source.index('def axes'))
    end=source.index('        return p',start)
    source=source[:start]+source[end:]
    source=source.replace('[0,.1,.2,.3,.4],[-20,0,40,80,100]','list(np.arange(9)*.05),list(range(-20,101,20))')
    source=source.replace('yy=493+k*26;d.line((117,yy+10,151,yy+10)','yy=485+k*24;d.line((110,yy+10,135,yy+10)')
    r.__dict__['ScaledDraw']=ScaledDraw;exec(source,r.__dict__)
    r.render(data,len(data[0])-1).save(OUT/'sector_clean.png')
    frames=(r.render(data,round(min(i,288)*40000/288)) for i in range(337))
    encode(OUT/'sector_clean.mp4',frames,'3840x2160',24)
if __name__=='__main__':
    if sys.argv[-1]=='sector':sector()
    else:carts()
