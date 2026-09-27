from pathlib import Path
from zipfile import ZipFile
from copy import copy

# Reuse the native Office Math construction helpers, without running the old design.
exec(Path('build/design_slides33_35.py').read_text(encoding='utf-8-sig').split("with ZipFile(B/'original.pptx') as zin:")[0])
B=Path('build/slides33_35_signals')
BLUE=TEAL=INK

def under(c): return bar(r(c))
def tilde(c,dual=False): return acc(under(c) if dual else r(c),'̃')
def system(rows):
    return delim('<m:eqArr><m:eqArrPr>'+ctrl()+'</m:eqArrPr>'+''.join('<m:e>'+v+'</m:e>' for v in rows)+'</m:eqArr>','{','')

def filter_system(dual=False,naive=False):
    name=tr(theta()) if naive else dt() if dual else theta()
    gain=st(kval()) if dual else kval()
    gain_matrix=[[r('𝐼'),r('−')+gain],[r('0'),r('𝐼')]] if naive else [[r('𝐼'),r('0')],[r('−')+gain,r('𝐼')]]
    inputs=mat([[under('𝑦')],[under('𝑢')]]) if dual else mat([[r('𝑦')],[r('𝑢')]])
    outputs=mat([[tilde('𝑦',dual)],[tilde('𝑢',dual)]])
    return name+r(' := ')+system([outputs+r('=')+mat(gain_matrix)+inputs])

def prepare_plain(doc,num,title):
    tree=doc.getElementsByTagName('p:spTree')[0]
    keep={'2','3','4','5','34','35','36','37','52','53','55','61','200','201'}
    for node in list(tree.childNodes):
        if node.nodeType==node.ELEMENT_NODE and shapeid(node) not in keep|{None,'1'}:
            tree.removeChild(node)
    for node in list(doc.getElementsByTagName('p:timing')):node.parentNode.removeChild(node)
    s=Slide(doc,num)
    for node in tree.childNodes:
        if node.nodeType==node.ELEMENT_NODE and shapeid(node)=='2':
            node.getElementsByTagName('a:t')[0].firstChild.data=title
    for field in doc.getElementsByTagName('a:fld'):
        if field.getAttribute('type')=='slidenum':
            for t in field.getElementsByTagName('a:t'):t.firstChild.data=str(num)
    return s

def replace_filter_label(s):
    for node in list(s.tree.childNodes):
        if node.nodeType==node.ELEMENT_NODE and shapeid(node)=='53':s.tree.removeChild(node)
    s.eq('Dual filter diagram label',224,266,65,35,lambda:dt(),22)

with ZipFile('build/slides33_34/original.pptx') as diagrams,ZipFile(B/'original.pptx') as current:
    docs={33:D.parseString(diagrams.read('ppt/slides/slide33.xml')),
          34:D.parseString(diagrams.read('ppt/slides/slide34.xml')),
          35:D.parseString(diagrams.read('ppt/slides/slide34.xml'))}
    s=prepare_plain(docs[33],33,'Alternative controller schematic')
    s.text('Plant label',384,84,298,22,'Take the state-feedback system',14)
    s.eq('Plant',391,109,293,43,lambda:system([r('𝑇')+acc(r('𝑥'))+r('=𝐴𝑥+')+bu()+r('𝑢'),r('𝑦=𝑥,   𝑢=')+kval()+r('𝑦')]),16)
    s.eq('Stage1 filter signal system',383,158,307,60,lambda:filter_system(),16)
    s.text('Stage2 thus',384,220,298,21,'Thus',14)
    s.eq('Stage2 outputs',391,243,293,44,lambda:system([tilde('𝑦')+r('=𝑦=𝑥'),tilde('𝑢')+r('=𝑢−')+kval()+r('𝑦=0')]),17)
    s.text('Stage3 substitution',384,296,298,21,'Filling in',14)
    s.eq('Stage3 closed loop',391,318,293,26,lambda:r('𝑇')+acc(r('𝑥'))+r('=')+delim(r('𝐴+')+bu()+kval())+r('𝑥'),17)
    s.text('Stage3 conclusion',36,354,648,22,'The controller enforces a zero residual.',16,RED,True)

    s=prepare_plain(docs[34],34,'Transposing the systems')
    s.text('Dimension convention',36,81,333,17,'For this illustration, state and input have equal dimension.',10.5,GRAY)
    s.eq('Stage1 transposed plant',383,88,307,57,lambda:tr(r('𝐺'))+r(': ')+system([st(r('𝑇'))+acc(under('𝑥'))+r('=')+st(r('𝐴'))+under('𝑥')+r('+')+under('𝑢'),under('𝑦')+r('=')+st(bu())+under('𝑥')]),16)
    s.eq('Stage1 transposed controller',383,154,307,25,lambda:tr(kval())+r(': ')+under('𝑢')+r('=')+st(kval())+under('𝑦'),16)
    s.eq('Stage1 transposed filter signal system',383,180,307,54,lambda:filter_system(True,True),15.5)
    s.text('Stage2 second output label',384,237,300,20,'Read the second output:',13)
    s.eq('Stage2 second output',391,258,293,28,lambda:tilde('𝑢',True)+r('=')+under('𝑢'),21)
    s.text('Stage3 substitute controller label',384,291,300,20,'Substitute the dual controller:',13)
    s.eq('Stage3 residual',391,312,293,30,lambda:tilde('𝑢',True)+r('=')+st(kval())+under('𝑦')+r('≠0',RED),21)
    s.text('Stage3 qualification',558,319,120,18,'in general',11.5,GRAY)
    s.text('Stage3 conclusion',36,354,648,22,'The residual is not forced to zero: this filter connection is wrong.',15.5,RED,True)

    s=prepare_plain(docs[35],35,'The dual filter')
    replace_filter_label(s)
    s.text('Stage1 introduction',384,83,298,22,'Use the dual filter',14)
    s.eq('Stage1 definition',383,109,307,38,lambda:dt()+r(':=')+sup(delim(st(acc(r('𝐽'),'̂'))+tr(theta())+acc(r('𝐽'),'̂')),r('−1')),18)
    s.eq('Stage1 exchange',383,151,307,39,lambda:acc(r('𝐽'),'̂')+r('=')+mat([[r('0'),r('𝐼')],[r('−𝐼'),r('0')]]),14)
    s.eq('Stage2 dual filter signal system',383,200,307,54,lambda:filter_system(True),15.5)
    s.text('Stage3 substitution',384,257,298,21,'Filling in',14)
    s.eq('Stage3 dual system',383,280,308,64,lambda:system([
        st(r('𝑇'))+acc(under('𝑥'))+r('=')+delim(st(r('𝐴'))+r('+')+st(kval())+st(bu()))+under('𝑥'),
        tilde('𝑦',True)+r('=')+st(bu())+under('𝑥'),
        tilde('𝑢',True)+r('=')+under('𝑢')+r('−')+st(kval())+under('𝑦')+r('=0')]),16)
    s.text('Stage3 conclusion',36,354,648,22,'The dual filter restores the zero residual.',16,RED,True)

    edits={f'ppt/slides/slide{part}.xml':docs[n].toxml(encoding='UTF-8') for n,part in [(33,33),(34,34),(35,45)]}
    edits['ppt/slides/_rels/slide45.xml.rels']=diagrams.read('ppt/slides/_rels/slide34.xml.rels')
    with ZipFile(B/'staged.pptx','w') as out:
        for info in current.infolist():out.writestr(copy(info),edits.get(info.filename,current.read(info.filename)))
print('Restored original diagram structure and slide titles; native editable equations on slides 33–35.')
