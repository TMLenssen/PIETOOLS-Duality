from pathlib import Path
import sys
base=Path('build/slide33_cleanup');sys.path.insert(0,str(base/'fonttools'))
from fontTools.ttLib import TTFont,newTable
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
f=TTFont(base/'latinmodern-math.otf');gs=f.getGlyphSet();glyphs={}
for name in f.getGlyphOrder():
 pen=TTGlyphPen(gs);gs[name].draw(Cu2QuPen(pen,1.0,reverse_direction=True));glyphs[name]=pen.glyph()
f['glyf']=newTable('glyf');f['glyf'].glyphs=glyphs;f['glyf'].glyphOrder=f.getGlyphOrder()
f['loca']=newTable('loca');f['maxp']=newTable('maxp');f['maxp'].tableVersion=0x10000
for name in ['maxZones','maxTwilightPoints','maxStorage','maxFunctionDefs','maxInstructionDefs','maxStackElements','maxSizeOfInstructions']:setattr(f['maxp'],name,0)
f['maxp'].maxZones=1
f['post'].formatType=2.0;f['post'].extraNames=[];f['post'].mapping={};f['post'].glyphOrder=f.getGlyphOrder()
del f['CFF '];f.sfntVersion='\x00\x01\x00\x00'
for r in f['name'].names:
 if r.nameID in [1,4,16]:value='Computer Modern Office'
 elif r.nameID==6:value='ComputerModernOffice-Regular'
 elif r.nameID==3:value='Computer Modern Office 1.959 TTF'
 else:continue
 r.string=value.encode(r.getEncoding())
f.save(base/'computer-modern-office.ttf')
s=Path('build/install_latin_modern_math.ps1').read_text(encoding='utf-8-sig').replace('latinmodern-math.otf','computer-modern-office.ttf').replace('Latin Modern Math','Computer Modern Office').replace('(OpenType)','(TrueType)')
Path('build/install_computer_modern_office.ps1').write_text(s,encoding='utf-8-sig')
print('Prepared TrueType version with the original math layout tables.')
