from pathlib import Path
from PIL import Image,ImageDraw
import subprocess,json
B=Path(__file__).resolve().parent
for name in ['zoom','gaps','filter','stability']:
 dur=float(json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(B/(name+'.mp4'))]))['format']['duration'])
 times=[.5,dur*.2,dur*.4,dur*.6,dur*.8,dur-.3]
 canvas=Image.new('RGB',(1280,3*382),'#dddddd');draw=ImageDraw.Draw(canvas)
 for k,t in enumerate(times):
  out=B/f'{name}-{k}.png';subprocess.run(['ffmpeg','-y','-loglevel','error','-ss',str(t),'-i',str(B/(name+'.mp4')),'-frames:v','1',str(out)],check=True)
  im=Image.open(out).resize((640,360));x=k%2*640;y=k//2*382;canvas.paste(im,(x,y+22));draw.text((x+5,y+4),f'{name} {t:.2f}s',fill='black')
 canvas.save(B/(name+'-contact.png'))
