from pathlib import Path
B=Path(__file__).resolve().parent;P=B.parent/'sector_dissipativity_story'
p=(P/'finish.py').read_text()
p=p.replace('[34,35,36,37,40]','[34,35,36,39]').replace('[33,34,35,36,37,39,40]','[33,34,35,36,39]')
p=p.replace("[('zoom',[33,34]),('gaps',[35]),('filter',[36,37]),('stability',[39,40])]","[('zoom',[33,34,35]),('gaps',[35]),('filter',[36]),('stability',[38,39])]")
p=p.replace('Packaged 56 slides','Packaged 55 slides').replace('sectorstory','sectorrefinement').replace('rIdSectorStory','rIdSectorRefinement');(B/'finish.py').write_text(p)
p=(P/'verify.ps1').read_text().replace('-ne 56','-ne 55').replace('56 slides','55 slides');(B/'verify.ps1').write_text(p)
(B/'contact.py').write_text((P/'contact.py').read_text())
p=(P/'install.ps1').read_text().replace('Before sector dissipativity sequence','Before sector schematic refinement').replace('@(33,34,35,36,37,39,40)','@(34,35,36,39)');(B/'install.ps1').write_text(p)
