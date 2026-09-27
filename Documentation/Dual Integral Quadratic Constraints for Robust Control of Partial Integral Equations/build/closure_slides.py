from pathlib import Path
from zipfile import ZipFile
from copy import copy

# Reuse the native Office Math construction helpers, without running the old design.
exec(Path('build/design_slides33_35.py').read_text(encoding='utf-8-sig').split("with ZipFile(B/'original.pptx') as zin:")[0])
B=Path('build/slides33_35_closure')
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
          35:D.parseString(diagrams.read('ppt/slides/slide34.xml')),
          36:D.parseString(diagrams.read('ppt/slides/slide34.xml'))}
    s=prepare_plain(docs[33],33,'Absorbing the controller into the filter')
    s.eq('Open plant',36,78,335,24,lambda:r('𝐺:  𝑇')+acc(r('𝑥'))+r('=𝐴𝑥+')+bu()+r('𝑢,  𝑦=𝑥'),15.5)
    s.text('Stage1 expected heading',384,80,300,20,'What do we expect?',14,bold=True)
    s.eq('Stage1 expected loop',390,102,294,23,lambda:r('𝑢=')+kval()+r('𝑦  ⇒  𝑇')+acc(r('𝑥'))+r('=')+delim(r('𝐴+')+bu()+kval())+r('𝑥'),15.5)
    s.text('Stage2 calculation heading',384,138,300,20,'What do we get?',14,bold=True)
    s.eq('Stage2 filter signal system',383,160,307,49,lambda:filter_system(),15.5)
    s.eq('Stage2 rewrite input',390,214,294,26,lambda:tilde('𝑢')+r('=𝑢−')+kval()+r('𝑦  ⇔  𝑢=')+kval()+r('𝑦+')+tilde('𝑢'),16.5)
    s.eq('Stage2 transformed plant',383,245,307,43,lambda:system([r('𝑇')+acc(r('𝑥'))+r('=')+delim(r('𝐴+')+bu()+kval())+r('𝑥+')+bu()+tilde('𝑢'),tilde('𝑦')+r('=𝑦=𝑥')]),16)
    s.text('Stage3 check heading',384,301,300,20,'Is this correct?',14,bold=True)
    s.eq('Stage3 closure',390,324,294,23,lambda:tilde('𝑢')+r('=0  ⇔  𝑢=')+kval()+r('𝑦'),18)
    s.text('Stage3 conclusion',36,354,648,22,'Yes: zero filtered input recovers the original closed loop.',16,RED,True)

    s=prepare_plain(docs[34],34,'Transposing the systems')
    s.text('Dimension convention',36,81,333,17,'For this illustration, state and input have equal dimension.',10.5,GRAY)
    s.text('Stage1 expected heading',384,80,300,20,'What do we expect?',14,bold=True)
    s.eq('Stage1 expected closure',390,105,294,27,lambda:tilde('𝑢',True)+r('=0  ⇔  ')+under('𝑢')+r('=')+st(kval())+under('𝑦'),18)
    s.text('Stage2 calculation heading',384,144,300,20,'What do we get?',14,bold=True)
    s.eq('Stage2 transposed plant',383,170,307,48,lambda:tr(r('𝐺'))+r(': ')+system([st(r('𝑇'))+acc(under('𝑥'))+r('=')+st(r('𝐴'))+under('𝑥')+r('+')+under('𝑢'),under('𝑦')+r('=')+st(bu())+under('𝑥')]),15.5)
    s.eq('Stage2 transposed filter signal system',383,229,307,51,lambda:filter_system(True,True),15.5)
    s.text('Stage3 check heading',384,288,300,20,'Is this correct?',14,bold=True)
    s.eq('Stage3 residual',390,310,294,29,lambda:tilde('𝑢',True)+r('=')+under('𝑢')+r('=')+st(kval())+under('𝑦')+r('≠0',RED),19)
    s.text('Stage3 qualification',390,339,294,14,'Generally nonzero under dual feedback.',10.5,GRAY)
    s.text('Stage3 conclusion',36,357,648,20,'No: zero filtered input imposes the wrong constraint.',16,RED,True)

    s=prepare_plain(docs[35],35,'The dual operation')
    replace_filter_label(s)
    s.text('Stage1 expected heading',384,84,300,20,'What do we expect?',14,bold=True)
    s.text('Stage1 expected description',384,109,296,47,'Filtering the dual system must give\nthe dual of the transformed system.',14)
    s.text('Stage2 operation heading',384,170,300,20,'What do we get?',14,bold=True)
    s.eq('Stage2 definition',383,198,307,39,lambda:dt()+r(':=')+sup(delim(st(acc(r('𝐽'),'̂'))+tr(theta())+acc(r('𝐽'),'̂')),r('−1')),21)
    s.eq('Stage2 exchange',383,243,307,39,lambda:acc(r('𝐽'),'̂')+r('=')+mat([[r('0'),r('𝐼')],[r('−𝐼'),r('0')]]),16)
    s.text('Stage3 check heading',384,298,300,20,'Is this correct?',14,bold=True)
    s.text('Stage3 check description',384,323,299,23,'Recover the expected dual closed loop.',13.5)
    s.text('Stage3 conclusion',36,354,648,22,'Next: apply this operation and verify the resulting system.',16,RED,True)

    s=prepare_plain(docs[36],36,'Applying the dual filter')
    replace_filter_label(s)
    s.text('Stage1 expected heading',384,80,300,20,'What do we expect?',14,bold=True)
    s.eq('Stage1 expected dynamics',383,105,307,27,lambda:st(r('𝑇'))+acc(under('𝑥'))+r('=')+delim(st(r('𝐴'))+r('+')+st(kval())+st(bu()))+under('𝑥'),16.5)
    s.text('Stage2 calculation heading',384,144,300,20,'What do we get?',14,bold=True)
    s.eq('Stage2 dual filter signal system',383,168,307,51,lambda:filter_system(True),15.5)
    s.eq('Stage2 rewrite input',390,227,294,26,lambda:under('𝑢')+r('=')+st(kval())+under('𝑦')+r('+')+tilde('𝑢',True),18)
    s.eq('Stage2 driven dual system',383,259,307,49,lambda:system([
        st(r('𝑇'))+acc(under('𝑥'))+r('=')+delim(st(r('𝐴'))+r('+')+st(kval())+st(bu()))+under('𝑥')+r('+')+tilde('𝑢',True),
        tilde('𝑦',True)+r('=')+st(bu())+under('𝑥')]),15.5)
    s.text('Stage3 check heading',384,314,300,20,'Is this correct?',14,bold=True)
    s.eq('Stage3 closure',390,337,294,23,lambda:tilde('𝑢',True)+r('=0  ⇔  ')+under('𝑢')+r('=')+st(kval())+under('𝑦'),17)
    s.text('Stage3 conclusion',36,361,648,20,'Yes: zero filtered input recovers the dual closed loop.',16,RED,True)

    pres=D.parseString(current.read('ppt/presentation.xml'));lst=pres.getElementsByTagName('p:sldIdLst')[0]
    rels=D.parseString(current.read('ppt/_rels/presentation.xml.rels'))
    relmap={e.getAttribute('Id'):'ppt/'+e.getAttribute('Target') for e in rels.getElementsByTagName('Relationship')}
    existing=list(lst.getElementsByTagName('p:sldId'))
    targetparts={n:relmap[existing[n-1].getAttribute('r:id')] for n in [33,34,35]}
    edits={part:docs[n].toxml(encoding='UTF-8') for n,part in targetparts.items()}
    edits['ppt/slides/slide46.xml']=docs[36].toxml(encoding='UTF-8')
    edits['ppt/slides/_rels/'+Path(targetparts[35]).name+'.rels']=diagrams.read('ppt/slides/_rels/slide34.xml.rels')
    edits['ppt/slides/_rels/slide46.xml.rels']=diagrams.read('ppt/slides/_rels/slide34.xml.rels')
    rid='rId'+str(max(int(e.getAttribute('Id')[3:]) for e in rels.getElementsByTagName('Relationship'))+1)
    rr=rels.createElement('Relationship');rr.setAttribute('Id',rid);rr.setAttribute('Type',NS['r']+'/slide');rr.setAttribute('Target','slides/slide46.xml');rels.documentElement.appendChild(rr)
    entries=list(lst.getElementsByTagName('p:sldId'))
    new=pres.createElement('p:sldId');new.setAttribute('id',str(max(int(n.getAttribute('id')) for n in entries)+1));new.setAttributeNS(NS['r'],'r:id',rid);lst.insertBefore(new,entries[35])
    types=D.parseString(current.read('[Content_Types].xml'));ov=types.createElement('Override');ov.setAttribute('PartName','/ppt/slides/slide46.xml');ov.setAttribute('ContentType','application/vnd.openxmlformats-officedocument.presentationml.slide+xml');types.documentElement.appendChild(ov)
    edits.update({'ppt/presentation.xml':pres.toxml(encoding='UTF-8'),'ppt/_rels/presentation.xml.rels':rels.toxml(encoding='UTF-8'),'[Content_Types].xml':types.toxml(encoding='UTF-8')})
    with ZipFile(B/'staged.pptx','w') as out:
        for info in current.infolist():out.writestr(copy(info),edits.pop(info.filename,current.read(info.filename)))
        for name,data in edits.items():out.writestr(name,data)
print('Restored original diagram structure and slide titles; native editable equations on slides 33–35.')
