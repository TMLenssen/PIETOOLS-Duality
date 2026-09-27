from pathlib import Path
import re,json
BASE=Path(r'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\A mu Analysis and Synthesis Framework for Infinite Dimensional Systems - Version 3')
OUT=Path(__file__).parent/'lfr_library'
OUT.mkdir(exist_ok=True)
source=(BASE/'Presentation/presentation.tex').read_text(encoding='utf-8')
source='\n'.join(re.sub(r'(?<!\\)%.*','',line) for line in source.splitlines())
rows=[]
for m in re.finditer(r'\\(lfrdiagram|observerdiagram)\s*\[',source):
    start=m.end();level=1;braces=0;i=start
    while level:
        c=source[i]
        if c=='{':braces+=1
        if c=='}':braces-=1
        if not braces:
            if c=='[':level+=1
            if c==']':level-=1
        i+=1
    text=source[start:i-1]
    row={'id':len(rows)+1,'macro':m.group(1),'line':source[:m.start()].count('\n')+1,'options':text}
    rows.append(row)
    print(row['id'],row['macro'],'line',row['line'],re.sub(r'\s+',' ',text))
(OUT/'source_calls.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
