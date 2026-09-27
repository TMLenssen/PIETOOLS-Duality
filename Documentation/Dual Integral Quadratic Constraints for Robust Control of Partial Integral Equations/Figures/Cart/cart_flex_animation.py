"""Rigid versus flexible cart: two separate, clean, slide-ready MP4 videos.

Run with Python + numpy + Pillow + pymupdf; ffmpeg and pdflatex must be on PATH.
An ideal base-position servo drives the same carriage in both panels.
The right cart carries a cantilevered frame, approximated by three bending
modes of an Euler-Bernoulli beam. Use --help to adjust parameters.
Example: python Figures/Cart/cart_flex_animation.py --fast-speed 8 --frequency-hz 4

The base servo is ideal and maintains identical motion in both models.
The frame has a clamped base, free tip, and Kelvin-Voigt bending damping.
q(t) is cart translation; w(t,s) is transverse displacement relative to the
moving cart, at position s along the frame. There is no spatial coordinate
in the rigid model. The flexible model uses
rho*A*(w_tt(t,s)+q_ddot(t)) + EI*w_ssss(t,s) + eta*w_tssss(t,s) = 0.
The damping parameter is the first-mode damping ratio: eta/EI=2*zeta/omega_1.
Tip deflection is magnified for visibility; no feedback instability is modeled.
"""
from pathlib import Path
import argparse
import shutil
import subprocess
import numpy as np
import pymupdf
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
W, H, FPS, DURATION = 960, 540, 30, 10
DT = 1/1200
PARAMS = dict(distance_mm=150.0, gentle_speed=1.6, fast_speed=10.0,
              frequency_hz=3.0, damping_percent=1.8, magnification=3.0)
ZETA, OMEGA1 = PARAMS['damping_percent'], 2*np.pi*PARAMS['frequency_hz']
BETA = np.array([1.875104068711961, 4.694091132974174, 7.854757438237612])
OMEGA = OMEGA1*(BETA/BETA[0])**2
SIGMA = (np.cosh(BETA)+np.cos(BETA))/(np.sinh(BETA)+np.sin(BETA))
S = np.linspace(0, 1, 81)


def shapes(s):
    z = BETA[:, None]*np.atleast_1d(s)
    return np.cosh(z)-np.cos(z)-SIGMA[:, None]*(np.sinh(z)-np.sin(z))


SHAPE = shapes(S)
grid = np.linspace(0, 1, 4097)
phi = shapes(grid)
PARTICIPATION = np.trapezoid(phi, grid, axis=1)/np.trapezoid(phi**2, grid, axis=1)


def command(t):
    return PARAMS['distance_mm']/1000 if 1 <= t < 9 or 12 <= t < 15 else 0.0


def dynamics(t, y):
    # Base servo has equal, ideal motion on both carts. Flexibility is driven by
    # its acceleration; this isolates structural settling from base tracking.
    wn = PARAMS['gentle_speed'] if t < 9 else PARAMS['fast_speed']
    acc = wn**2*(command(t)-y[0])-2*wn*y[1]
    # Kelvin-Voigt viscosity gives mode n a damping coefficient
    # (eta/EI)*omega_n^2, with eta/EI=2*zeta_1/omega_1.
    damping=2*ZETA/OMEGA1*OMEGA**2
    return np.r_[y[1], acc, y[5:8], -damping*y[5:8]-OMEGA**2*y[2:5]-PARTICIPATION*acc]


def simulate(dt=DT):
    y = np.zeros(8)
    result = []
    stride = round(1/(FPS*dt))
    for step in range(round(DURATION/dt)+1):
        t = step*dt
        if step % stride == 0:
            result.append(y.copy())
        # Evaluate interval endpoints from the left at command discontinuities.
        k1 = dynamics(t+1e-10, y)
        k2 = dynamics(t+dt/2, y+dt*k1/2)
        k3 = dynamics(t+dt/2, y+dt*k2/2)
        k4 = dynamics(t+dt-1e-10, y+dt*k3)
        y += dt*(k1+2*k2+2*k3+k4)/6
    return np.array(result)


DATA = None
EQUATIONS = None
POSITION_SCALE, DEFLECTION_SCALE, GRAPH_LIMIT = 800.0, 2400.0, 60.0
BLUE, RED, INK, MUTED = '#147d92', '#c8102e', '#192b3c', '#607083'
TARGET = '#b87916'
try:
    AXIS_FONT = ImageFont.truetype('timesi.ttf', 22)
except OSError:
    AXIS_FONT = ImageFont.load_default(size=22)


def frame(i, flexible=False):
    """Moving cart, commanded target, displacement markers, and equations."""
    im = Image.new('RGB', (W, H), 'white')
    d = ImageDraw.Draw(im)
    q = DATA[i, 0]
    deformation = DATA[i, 2:5] @ SHAPE if flexible else np.zeros(len(S))
    base = W/2 + POSITION_SCALE*(q-PARAMS['distance_mm']/2000)
    target = W/2 + POSITION_SCALE*(command(i/FPS)-PARAMS['distance_mm']/2000)
    # The target follows the commanded position, independently of the cart.
    for y in range(80, 415, 18):
        d.line([(target,y),(target,min(y+10,415))],fill=TARGET,width=2)
    d.text((target,67), 'Target r(t)', font=AXIS_FONT, fill=TARGET, anchor='mb')
    color = BLUE if flexible else RED
    mast = list(zip(base + DEFLECTION_SCALE*deformation, 353 - 208*S))
    d.polygon([(x-7,y) for x,y in mast]+[(x+7,y) for x,y in reversed(mast)],fill=color)
    tx = base + DEFLECTION_SCALE*deformation[-1]
    # The end cap follows the local beam tangent. It is a visual marker,
    # with no added point mass in the beam model.
    slope = DEFLECTION_SCALE*(deformation[-1]-deformation[-2])/(208*(S[-1]-S[-2]))
    angle = np.arctan(slope)
    local = np.array([[-40,-12],[40,-12],[40,12],[-40,12]])
    rotation = np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])
    cap = local@rotation.T + [tx,145]
    d.polygon([tuple(point) for point in cap],fill=color)
    d.rounded_rectangle((base-112,343,base+112,377),radius=8,fill=color)
    # This reference axis translates with the cart but does not bend.
    for y in range(89, 377, 14):
        d.line([(base,y),(base,min(y+7,377))],fill=MUTED,width=2)
    # The marker sits directly on the top cap. Its horizontal distance
    # from the reference axis is the displayed (magnified) tip deflection.
    marker_y = 145
    d.line([(base,marker_y),(tx,marker_y)],fill=INK,width=2)
    d.line([(base,marker_y-5),(base,marker_y+5)],fill=INK,width=2)
    d.ellipse((tx-6,marker_y-6,tx+6,marker_y+6),fill=INK)
    d.line([(tx+8,marker_y),(tx+46,marker_y)],fill=INK,width=1)
    tip_label = 'q(t) + w(t,L)' if flexible else 'q(t)'
    d.text((tx+52,marker_y), tip_label, font=AXIS_FONT,
           fill=INK, anchor='lm')
    if flexible:
        d.text((base+10,89), 's', font=AXIS_FONT, fill=INK, anchor='lt')
    for wheel in [base-74,base+74]:
        d.ellipse((wheel-20,373,wheel+20,413),fill=INK)
        d.ellipse((wheel-6,387,wheel+6,399),fill='white')
        angle=q*POSITION_SCALE/20
        d.line([(wheel,393),(wheel+15*np.cos(angle),393+15*np.sin(angle))],fill='#9daebc',width=2)
    d.line([(base,377),(base,383)],fill=INK,width=1)
    d.ellipse((base-6,371,base+6,383),fill=INK)
    d.text((base,386), 'q(t)', font=AXIS_FONT, fill=INK, anchor='mt',
           stroke_width=2, stroke_fill='white')
    d.line([(90,415),(870,415)],fill='#d5dce3',width=2)
    if EQUATIONS is not None:
        im.paste(EQUATIONS[int(flexible)], (0,424))
    return im


def render_equations():
    build=OUT.parent.parent/'build'
    build.mkdir(exist_ok=True)
    result=subprocess.run(['pdflatex','-interaction=nonstopmode','-halt-on-error',
                           '-output-directory='+str(build),str(OUT/'cart_equations.tex')],
                          capture_output=True,text=True)
    if result.returncode:
        raise RuntimeError(result.stdout[-3000:])
    images=[]
    with pymupdf.open(build/'cart_equations.pdf') as document:
        if len(document)!=2:
            raise RuntimeError('Expected exactly two equation panels')
        for page in document:
            pix=page.get_pixmap(matrix=pymupdf.Matrix(W/page.rect.width,W/page.rect.width),alpha=False)
            images.append(Image.frombytes('RGB',(pix.width,pix.height),pix.samples))
    return images


def update_scales():
    global POSITION_SCALE, DEFLECTION_SCALE, GRAPH_LIMIT
    deformation=DATA[:,2:5]@SHAPE
    extent=PARAMS['distance_mm']/1000+2*PARAMS['magnification']*np.max(abs(deformation))
    POSITION_SCALE=min(800.0,380/max(extent,1e-12))
    DEFLECTION_SCALE=POSITION_SCALE*PARAMS['magnification']
    tip=deformation[:,-1]*1000
    GRAPH_LIMIT=max(3.0,np.ceil(np.max(abs(tip))*1.1/3)*3)


def main():
    global DATA,ZETA,OMEGA1,OMEGA,DT,EQUATIONS
    parser=argparse.ArgumentParser(description=__doc__)
    ranges={'distance_mm':(1,300),'gentle_speed':(.2,30),'fast_speed':(.2,30),
            'frequency_hz':(.5,10),'damping_percent':(0,30),'magnification':(1,10)}
    for key,value in PARAMS.items():
        parser.add_argument('--'+key.replace('_','-'),type=float,default=value,
                            help=f'Default {value:g}; range {ranges[key][0]}–{ranges[key][1]}')
    parser.add_argument('--output',default='cart',help='Output prefix inside Figures/Cart; writes PREFIX_rigid.mp4 and PREFIX_flexible.mp4')
    parser.add_argument('--preview-only',action='store_true',help='Only render a PNG preview of each cart')
    parser.add_argument('--validate',action='store_true',help='Also compare against a simulation with half the time step')
    args=parser.parse_args()
    for key,(lo,hi) in ranges.items():
        value=getattr(args,key)
        if not np.isfinite(value) or not lo<=value<=hi:
            parser.error(f'--{key.replace("_","-")} must be between {lo} and {hi}')
        PARAMS[key]=value
    if not args.output or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in args.output):
        parser.error('--output must be a basename containing letters, numbers, underscores or hyphens')
    ZETA=PARAMS['damping_percent']/100
    OMEGA1=2*np.pi*PARAMS['frequency_hz']
    OMEGA=OMEGA1*(BETA/BETA[0])**2
    DT=1/(FPS*max(40,int(np.ceil(max(OMEGA)/FPS/.12))))
    DATA=simulate(DT)
    if args.validate:
        fine=simulate(DT/2)
        assert np.max(abs(DATA[:,2:5]-fine[:,2:5])) < 1e-7, 'Modal displacement convergence failed'
        assert np.max(abs(DATA-fine)) < 2e-5, 'State convergence failed'
    assert np.max(abs(shapes([0]))) < 1e-12
    assert np.all(np.isfinite(DATA))
    tip=DATA[:,2:5]@SHAPE[:,-1]
    gentle=np.max(abs(tip[:9*FPS]))
    fast=np.max(abs(tip[9*FPS:]))
    print(f'Peak tip deflection: gentle {gentle*1000:.2f} mm; fast {fast*1000:.2f} mm.',flush=True)
    update_scales()
    EQUATIONS=render_equations()
    if args.preview_only:
        for name, flexible in [('rigid', False), ('flexible', True)]:
            frame(round(9.5*FPS), flexible).save(OUT/(args.output+'_'+name+'_preview.png'))
        print('Created previews.',flush=True)
        return
    executable=shutil.which('ffmpeg')
    if not executable: raise RuntimeError('ffmpeg is required')
    for name, flexible in [('rigid', False), ('flexible', True)]:
        target=OUT/(args.output+'_'+name+'.mp4')
        p=subprocess.Popen([executable,'-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(target)],stdin=subprocess.PIPE)
        try:
            for i in range(FPS*DURATION):
                p.stdin.write(frame(i,flexible).tobytes())
        finally:
            p.stdin.close()
        if p.wait():
            raise RuntimeError('Video encoding failed')
        print(f'Created {target.name}',flush=True)


if __name__=='__main__': main()
