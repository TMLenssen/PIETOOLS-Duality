from pathlib import Path
import sys
base=Path('build/slide33_cleanup');sys.path.insert(0,str(base/'fonttools'))
from fontTools.ttLib import TTFont
f=TTFont(base/'latinmodern-math.otf')
print('Embedding flags',f['OS/2'].fsType)
for feature in f['GSUB'].table.FeatureList.FeatureRecord:
 if feature.FeatureTag=='ssty':
  feature.Feature.LookupListIndex=[];feature.Feature.LookupCount=0
for r in f['name'].names:
 if r.nameID in [1,4,16]: value='Latin Modern Math PPT'
 elif r.nameID==6:value='LatinModernMathPPT-Regular'
 elif r.nameID==3:value='Latin Modern Math PPT 1.959; PowerPoint script compatibility'
 else:continue
 r.string=value.encode(r.getEncoding())
if 'CFF ' in f:
 cff=f['CFF '].cff;cff.fontNames=['LatinModernMathPPT-Regular'];cff.topDictIndex[0].FamilyName='Latin Modern Math PPT';cff.topDictIndex[0].FullName='Latin Modern Math PPT'
f.save(base/'latinmodern-math-ppt.otf')
p=Path('build/set_deck_math_font.py');s=p.read_text(encoding='utf-8-sig').replace("font='Latin Modern Math'","font='Latin Modern Math PPT'");p.write_text(s,encoding='utf-8')
script=Path('build/install_latin_modern_math.ps1').read_text(encoding='utf-8-sig').replace('latinmodern-math.otf','latinmodern-math-ppt.otf').replace('Latin Modern Math','Latin Modern Math PPT')
Path('build/install_latin_modern_math_ppt.ps1').write_text(script,encoding='utf-8-sig')
print('Prepared renamed font; script glyph variants disabled, glyph designs unchanged.')
