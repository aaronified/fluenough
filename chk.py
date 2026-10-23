import yaml,glob,collections,unicodedata
tg=collections.defaultdict(list); ids={}
files=glob.glob('*.yaml')
for f in files:
    d=yaml.safe_load(open(f))
    if not isinstance(d,dict) or 'cards' not in d: continue
    if d.get('kind') in('layer',): continue
    for c in d['cards']:
        if 'target' not in c or not isinstance(c,dict): continue
        ids.setdefault(c['id'],f)
        tg[c['target'].lower()].append((c['id'],f))
for t,v in tg.items():
    if len(v)>1: print('DUP',t,v)
new=['es-quantities','es-describing','es-quantities-sentences','es-describing-sentences']
for n in new:
    d=yaml.safe_load(open(n+'.yaml'))
    L=yaml.safe_load(open('en/es-en-'+n[3:]+'.yaml'))
    print('==',n)
    for c in d['cards']:
        l=L['cards'].get(c['id'],{})
        print(c['id'],c.get('target'),c.get('pos'),c.get('gender',''),'=',l.get('native'), '| ref' if 'ref' in c else '')
        for e in c.get('examples',[]) :
            for b in e['bases'] if isinstance(e.get('bases'),list) else []:
                if 'ref' in b and b['ref']==c['id']: print('SELFREF',c['id'])
                if 'ref' in b and b['ref'] not in ids: print('MISSING',b)
