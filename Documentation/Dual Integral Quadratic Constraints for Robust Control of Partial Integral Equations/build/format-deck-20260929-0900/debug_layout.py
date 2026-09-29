from format_deck import *
for pos in [6,15,21,34,43]:
 print('Slide',pos,paths[pos-1])
 for fn in ['source.pptx','formatted.pptx']:
  z=zipfile.ZipFile(ROOT/fn);d=M.parseString(z.read(paths[pos-1]));print(fn)
  for s in top_shapes(d):
   if name(s).lower() in ['title','title 1','footer placeholder 3','footer placeholder 4']:
    print(name(s),[x.toxml() for x in tags(s,'a:xfrm')])
