import yaml,sys,glob,os
for f in sys.argv[1:]:
    d=yaml.safe_load(open(f)); print('=====',f,d.get('id'),d.get('kind'))
    for k in ('name','description','theme'):
        if k in d: print(k,':',d[k])
    en={}
    lay=os.path.join(os.path.dirname(f),'en','zh-en-'+os.path.basename(f)[3:])
    if os.path.exists(lay): en=yaml.safe_load(open(lay)).get('cards',{})
    for c in d.get('cards',[]):
        print(c['id'],c.get('target'),'|',c.get('reading'),'|',c.get('pos'),c.get('words') if len(c.get('words') or [])>1 else '', {k:v for k,v in c.items() if k not in('id','target','reading','pos','words','examples','bases','ipa','confusables')})
        e=en.get(c['id'],{})
        if e: print('   EN',e.get('meaning') or e.get('gloss') or {k:v for k,v in e.items() if k!='examples'})
        for x in c.get('examples',[]) or []:
            print('    ex',x['target'],'|',x.get('reading'),'|',(e.get('examples') or {}).get(x['target']), '| bases', [ (b.get('word'),b.get('base') or b.get('ref')) for b in x.get('bases',[]) if isinstance(b,dict)])
        if c.get('bases'): print('   bases',[ (b.get('word'),b.get('base') or b.get('ref')) for b in c['bases'] if isinstance(b,dict)])
    for p in d.get('passages',[]):
        print('PASSAGE',p['id'],p.get('title'));[print('  ',s['text'],s.get('reading')) for s in p.get('sentences',[])]
        for q in p['questions']:print('  Q',q['id'],q['prompt'],q.get('options'),q['answer'])
