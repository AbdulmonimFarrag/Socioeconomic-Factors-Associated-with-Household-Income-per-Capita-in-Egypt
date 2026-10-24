#!/usr/bin/env python3
"""
Build the Egypt 2021 Household Dashboard from the two raw survey workbooks.

    python build_dashboard.py \
        --household  Egypt21_Household_Translated.xlsx \
        --individual Egypt21_Individual_Translated.xlsx \
        --template   dashboard_template.html \
        --out        Egypt_2021_Dashboard.html

Pipeline
  1. LOAD + CLEAN   read both workbooks, check keys/weights, map governorates, decode
                    Arabic room counts, treat blank asset cells as "does not own".
  2. SEGMENT        governorate (26) x area (urban/rural) x gender x age band,
                    income-per-person quintiles, head-education groups.
  3. STATISTICS     survey-weighted totals, shares, quartiles, means, KDE densities.
  4. INJECT         write the five data blocks (D, V, SB, XB, INC) into the HTML
                    template. Map boundaries and all chart code live in the template.
Requires: pandas, numpy, openpyxl.
"""
import argparse, json, re, sys
import warnings; warnings.filterwarnings("ignore")
import numpy as np, pandas as pd

# ------------------------------------------------------------------ settings
W      = 'Household weight'
AGE_BANDS = [-1, 14, 29, 44, 59, 200]            # 0-14, 15-29, 30-44, 45-59, 60+
ROOMS  = {'غرفة واحدة':1,'غرفتين':2,'ثلاث غرف':3,'اربع غرف':4,'خمس غرف':5,
          'ست غرف':6,'سبع غرف':7,'ثمان غرف':8,'تسع غرف':9,'عشر غرف':10}
VIOLIN_MIN_N = 30                                 # hide groups with fewer sampled households
VIOLIN_GRID  = 40                                 # density points
EDU_LEVELS   = ['None','Primary/Lower secondary','Secondary','Post secondary or equivalent','University','Postgraduate']
EDU_SHORT    = ['None','Primary/Lower','Secondary','Post-sec.','University','Postgrad.']

# dashboard column order for household aggregates
HK = ["r","a","w","p","e","inc","exp","food","hous","hlth","edu","trn","clo","com","rec","rst",
      "fr","wm","ac","net","pc","car","wh","ph","tv","sat","s0","s1","s2","pipe","d0","d1"]
# dashboard column order for person aggregates
IK = ["r","a","g","b","w","litD","lit","e25","e0","e1","e2","e3","e4","ins","dis","chr","ss",
      "s17","s17y","lfD","act","emp","une"]

def has(c):  return f'Has {c}'
ASSET_COLS = {'fr':'Has refrigerator,  freezer, water cooler, etc...','wm':'Has washing machine',
  'ac':'Has an air conditioner','net':'Has internet line and related equipments (router, USB, etc…)',
  'pc':'Has computer or laptop connected or not to an internet line','car':'Has a car, van, taxi, cart, etc …',
  'wh':'Has a water heater','ph':'Has telephone, cell phone, etc…','tv':'Has a TV, LCD, LED, etc...',
  'sat':'Has satellite dish, receiver, etc…'}
SPEND_COLS = {'inc':'Total disposable income','exp':'Total expenditures',
  'food':'Total food expenditures',                 # includes tobacco (original dashboard definition)
  'hous':'Housing and utilities','hlth':'Health','edu':'Education','trn':'Transport',
  'clo':'Clothing and footwear','com':'Communication','rec':'Recreation and culture','rst':'Restaurants and hotels'}

# cross-tab specifications: raw column, raw-label -> dashboard-label (None = drop, e.g. "Not stated")
def ident(*labels): return {l:l for l in labels}
XB_SPEC = [
 dict(n='Dwelling tenure', b='all households', u='households', i=0, o=0, src='h', col='Tenure of dwelling [Standardized version]',
      c=['Owned','Provided free','Rented'], map=ident('Owned','Provided free','Rented')),
 dict(n='Dwelling type', b='all households', u='households', i=0, o=0, src='h', col='Type of dwelling [Standardized version]',
      c=['Apartment','House','Others','Villa'], map=ident('Apartment','House','Others','Villa')),
 dict(n='Crowding (persons per room)', b='households (rooms reported)', u='households', i=0, o=1, src='h', col='__crowding__',
      c=['Under 1 per room','1 to 2 per room','2 to 3 per room','Over 3 (overcrowded)'], map=None),
 dict(n='Household composition', b='all households', u='households', i=0, o=0, src='h', col='Household composition',
      c=['1-2 adults, 1-2 children','1-2 adults, 3+ children','3+ adults, 0-1 child','1-2 adults, no child','3+ adults, 2-3 children','3+ adults, 4+ children'],
      map={'1-2 adults, 1-2 children':'1-2 adults, 1-2 children','1-2 adult, 3 or more children':'1-2 adults, 3+ children',
           '3 adults or more, 0-1 child':'3+ adults, 0-1 child','1-2 adults, no child':'1-2 adults, no child',
           '3 adults or more, 2-3 children':'3+ adults, 2-3 children','3 adults or more, 4 children or more':'3+ adults, 4+ children'}),
 dict(n='Garbage disposal', b='all households', u='households', i=0, o=0, src='h', col='Garbage disposal method',
      c=['Govt. collection','Thrown in a public bin','Private collector','Other','Burnt','Private company','Thrown in the streets','Used as food for animals'],
      map={'Collected by government services':'Govt. collection','Thrown in a public bin':'Thrown in a public bin','Collected by a garbage collector':'Private collector',
           'Other':'Other','Burnt':'Burnt','Collected by a private company':'Private company','Thrown in the streets':'Thrown in the streets','Used as food for animals':'Used as food for animals'}),
 dict(n='Sanitation', b='all households', u='households', i=0, o=0, src='h', col='Toilet facility',
      c=['Toilet, sewage-connected','Toilet, not sewage-connected'],
      map={'Yes and connected to sewage':'Toilet, sewage-connected','Yes and not connected to sewage':'Toilet, not sewage-connected'}),
 dict(n="Head's employment sector", b='households with a working head', u='households', i=0, o=0, src='h', col='Sector of employment of the head [Standardized version]',
      c=['Private sector','Government','Public sector','Joint/Cooperative','Other'], map=ident('Private sector','Government','Public sector','Joint/Cooperative','Other')),
 dict(n="Head's marital status", b='all households', u='households', i=0, o=0, src='h', col='Marital status of the head [Standardized version]',
      c=['Married','Widowed','Divorced / separated','Never married','Married polygamous'],
      map={'Married monogamous':'Married','Widowed':'Widowed','Divorced/Separated':'Divorced / separated','Never married':'Never married','Married polygamous':'Married polygamous'}),
 dict(n='Main occupation', b='employed people', u='people', i=1, o=0, src='i', col='Occupation classification  for the main job [Standardized version]',
      c=['Service & sales workers','Craft & trades workers','Skilled agri / fishery','Machine operators','Professionals','Managers & officials','Technicians','Other'],
      map={'Service workers and shop and market sales workers':'Service & sales workers','Craft and related trades workers':'Craft & trades workers',
           'Skilled agricultural and fishery workers':'Skilled agri / fishery','Plant and machine operators, and assemblers':'Machine operators','Professionals':'Professionals',
           'Legislators, senior officials and managers':'Managers & officials','Technicians and associate professionals':'Technicians','Clerks':'Other','Elementary occupations':'Other'}),
 dict(n='Industry', b='employed people', u='people', i=1, o=0, src='i', col='Industry classification  for the main job [Standardized version]',
      c=['Other services','Commerce','Agriculture and Fishing','Construction','Manufacturing','Transport & communication','Public Administration','Other'],
      map={'Other services':'Other services','Commerce':'Commerce','Agriculture and Fishing':'Agriculture and Fishing','Construction':'Construction','Manufacturing':'Manufacturing',
           'Transportation, Storage and Communication':'Transport & communication','Public Administration':'Public Administration',
           'Electricity and Utilities':'Other','Financial, Insurance and Real Estate':'Other','Mining':'Other'}),
 dict(n='Employment status', b='employed people', u='people', i=1, o=0, src='i', col='Status of Employment',
      c=['Employee','Self-employed','Employer','Unpaid family worker'],
      map={'Employee':'Employee','Own-account, self-employed':'Self-employed','Employer':'Employer','Contributing (unpaid) family worker':'Unpaid family worker'}),
 dict(n='Employment sector', b='employed people', u='people', i=1, o=0, src='i', col='Sector of employment [Standardized version]',
      c=['Private sector','Government','Public sector','Joint/Cooperative','Other'], map=ident('Private sector','Government','Public sector','Joint/Cooperative','Other')),
 dict(n='School type attended', b='students', u='people', i=1, o=0, src='i', col='Type of school attending',
      c=['Public','Private','Koranic','Other'], map=ident('Public','Private','Koranic','Other')),
 dict(n='Type of disability', b='people with a disability', u='people', i=1, o=0, src='i', col='Type of disability',
      c=['Physical (movement)','Blindness','Other','Mental / intellectual','Deafness'],
      map={'Physical (movement) disability':'Physical (movement)','Blindness':'Blindness','Other':'Other','Mental retardation':'Mental / intellectual','Deafness':'Deafness'}),
]
# NOTE: the label "Not stated" (and blanks) are intentionally excluded from the occupation,
# industry, employment-status, employment-sector and head-sector tables.

# ------------------------------------------------------------------ helpers
def r2(x): return round(float(x), 2)

def wquantile(x, w, q):
    """Survey-weighted quantile, mid-point interpolation (matches the dashboard)."""
    o = np.argsort(x, kind='stable'); xs, ws = x[o], w[o]
    cw = (np.cumsum(ws) - ws / 2) / ws.sum()
    return float(np.interp(q, cw, xs))

def load(args):
    hh  = pd.read_excel(args.household,  sheet_name='Data')
    ind = pd.read_excel(args.individual, sheet_name='Data')
    # ---- cleaning / integrity checks
    assert not hh['Unique unit identifier'].duplicated().any(), 'duplicate household ids'
    assert hh[W].notna().all() and (hh[W] > 0).all(), 'missing/non-positive weights'
    assert set(ind['Unique unit identifier']) <= set(hh['Unique unit identifier']), 'individuals without household'
    regions = sorted(hh['Region'].unique())
    assert len(regions) == 26, f'expected 26 governorates, got {len(regions)}'
    rid = {n: i for i, n in enumerate(regions)}
    for d in (hh, ind):
        d['r'] = d['Region'].map(rid).astype(int)
        d['a'] = (d['Urban/Rural residence'] == 'Rural').astype(int)      # 0 urban, 1 rural
    ind['g'] = (ind['Gender'] == 'Female').astype(int)                   # 0 male, 1 female
    ind['b'] = pd.cut(ind['Age'], AGE_BANDS, labels=False).astype(int)
    hh['rooms'] = hh['Number of rooms'].map(ROOMS).astype(float)          # Arabic text -> number
    print(f'households {len(hh):,} (weighted {hh[W].sum():,.1f}) | persons {len(ind):,} (weighted {ind[W].sum():,.1f})')
    return hh, ind, regions

# ------------------------------------------------------------------ blocks
def build_D(hh, ind, regions):
    w = hh[W]
    cols = {'w': w, 'p': w*hh['Number of persons'], 'e': w*hh['Number of earners']}
    for k, c in SPEND_COLS.items(): cols[k] = w*hh[c].fillna(0)
    for k, c in ASSET_COLS.items(): cols[k] = w*hh[c].notna()            # blank = does not own
    src = hh['Source of income']
    cols['s0'] = w*(src == 'Salaries and wages'); cols['s1'] = w*(src == 'Household business')
    cols['s2'] = w*(src == 'Remittances from country or abroad')
    cols['pipe'] = w*(hh['Water facilities'] == 'Piped supply')
    cols['d0'] = w*hh['Type of dwelling [Standardized version]'].isin(['Apartment','Villa'])   # apartment or villa
    cols['d1'] = w*(hh['Type of dwelling [Standardized version]'] == 'House')
    g = pd.concat(cols, axis=1).assign(r=hh['r'], a=hh['a']).groupby(['r','a']).sum().reset_index()
    H = [[int(row['r']), int(row['a'])] + [r2(row[k]) for k in HK[2:]] for _, row in g.iterrows()]

    a_ = ind[W]; age = ind['Age']; lit = ind['Literacy status']; edu = ind['Educational level [Standardized version]']
    sa = ind['School attendance status']; lf = ind['Labor force status in the current period']
    ma = ind['Main activity status in the current period [Standardized version]']
    a25 = age >= 25; s17 = (age >= 6) & (age <= 17); a15 = age >= 15
    pc = {'w': a_, 'litD': a_*((age >= 10) & lit.notna()), 'lit': a_*(lit == 'Can read AND write'), 'e25': a_*a25,
          'e0': a_*(a25 & edu.isna()), 'e1': a_*(a25 & (edu == 'Primary/Lower secondary')), 'e2': a_*(a25 & (edu == 'Secondary')),
          'e3': a_*(a25 & (edu == 'Post secondary or equivalent')), 'e4': a_*(a25 & edu.isin(['University','Postgraduate'])),
          'ins': a_*(ind['Health Insurance'] == 'Yes'), 'dis': a_*(ind['Disability status'] == 'Disabled'),
          'chr': a_*(ind['Chronic Disease'] == 'Yes'), 'ss': a_*(ind['Social Security'] == 'Yes'),
          's17': a_*s17, 's17y': a_*(s17 & (sa == 'Yes')), 'lfD': a_*(a15 & lf.isin(['Active','Inactive'])),
          'act': a_*(a15 & (lf == 'Active')), 'emp': a_*(a15 & (ma == 'Employed')), 'une': a_*(a15 & (ma == 'Unemployed'))}
    gi = pd.concat(pc, axis=1).assign(r=ind['r'], a=ind['a'], g=ind['g'], b=ind['b']).groupby(['r','a','g','b']).sum()
    I = []
    for (r, a) in g[['r','a']].itertuples(index=False):
        for gg in (0, 1):
            for b in range(5):
                row = gi.loc[(r, a, gg, b)] if (r, a, gg, b) in gi.index else None
                I.append([int(r), int(a), gg, b] + [r2(row[k]) if row is not None else 0.0 for k in IK[4:]])
    return {'R': regions, 'HK': HK, 'H': H, 'IK': IK, 'I': I}

def build_SB(hh, ind):
    ind = ind.assign(ss=(ind['Social Security'] == 'Yes'), bur=(ind['Disability status'] == 'Disabled') | (ind['Chronic Disease'] == 'Yes'))
    h = ind.groupby('Unique unit identifier').agg(ss=('ss','max'), bur=('bur','max'))
    m = hh.join(h, on='Unique unit identifier')
    k = (m['Water facilities'] != 'Piped supply').astype(int)*4 + (~m['ss'].fillna(False).astype(bool)).astype(int)*2 + m['bur'].fillna(False).astype(bool).astype(int)
    t = m[W].groupby([m['r'], m['a'], k]).sum().unstack(fill_value=0).reindex(columns=range(8), fill_value=0)
    return [[int(r), int(a)] + [r2(v) for v in row] for (r, a), row in t.iterrows()]

def build_INC(hh):
    pcap = hh['Total disposable income'] / hh['Number of persons']
    o = np.argsort(pcap.values, kind='stable'); cw = np.cumsum(hh[W].values[o]) / hh[W].sum()
    q = np.empty(len(hh), int); q[o] = np.minimum((cw*5 - 1e-9).astype(int), 4)   # weighted quintiles of income per person
    w = hh[W]
    src = [w*hh['Net wages and salaries'], w*hh['Self-employment income'],
           w*(hh['Income less expenses from rentals'].fillna(0) + hh['Property income'].fillna(0)), w*hh['Current transfers received']]
    rows = []
    for (r, a), idx in hh.groupby(['r','a']).groups.items():
        row = [int(r), int(a)]
        for k in range(5):
            sel = hh.index.isin(idx) & (q == k)
            row += [r2(s[sel].sum()/1e6) for s in src]
        rows.append(row)
    return rows

def build_XB(hh, ind):
    out = []
    rooms = hh['rooms']; crowd = pd.cut(hh['Number of persons']/rooms, [0,1,2,3,1e9], right=True, labels=False)
    for sp in XB_SPEC:
        df = hh if sp['src'] == 'h' else ind
        if sp['col'] == '__crowding__': lab = crowd.map(dict(enumerate(sp['c'])))
        else: lab = df[sp['col']].map(sp['map'])                              # unmapped / blank / "Not stated" -> NaN -> dropped
        keys = ['r','a'] + (['g'] if sp['i'] else [])
        t = df[W].groupby([df[k] for k in keys] + [lab]).sum().unstack(fill_value=0).reindex(columns=sp['c'], fill_value=0)
        t = t[t.sum(axis=1) > 0]
        rows = []
        for idx, row in t.iterrows():
            idx = idx if isinstance(idx, tuple) else (idx,)
            rows.append([int(v) for v in idx] + ([0] if not sp['i'] else []) * 0 + [r2(v) for v in row])
        # tables without gender keep the layout [r, a, 0, counts...] used by the dashboard
        if not sp['i']: rows = [[x[0], x[1], 0] + x[2:] for x in rows]
        out.append({k: sp[k] for k in ('n','b','u','i','o','c')} | {'r': rows})
    return out

def build_V(hh):
    pcap = hh['Total disposable income'] / hh['Number of persons']
    x_all = pcap.values; w_all = hh[W].values
    Y = int(round(wquantile(x_all, w_all, .98)))                              # 98th percentile of income per person caps the violin
    lab = hh['Educational level of the head [Standardized version]'].fillna('None')
    grid = np.linspace(0, Y, VIOLIN_GRID); S = {}
    for r in range(-1, 26):
        for a in (-1, 0, 1):
            m0 = ((hh['r'] == r) if r >= 0 else True) & ((hh['a'] == a) if a >= 0 else True)
            m0 = m0 & (pcap <= Y)                                             # drop extreme outliers
            if not np.any(m0): continue
            row = []
            for lv in EDU_LEVELS:
                m = m0 & (lab == lv); n = int(m.sum())
                if n < VIOLIN_MIN_N: row.append(0); continue
                x = pcap[m].values; ww = hh.loc[m, W].values
                a1, md, a3 = (wquantile(x, ww, p) for p in (.25, .5, .75))
                fence = a3 + 1.5*(a3 - a1); hi = x[x <= fence].max()
                sd = np.sqrt(np.cov(x, aweights=ww)); iqr = np.subtract(*np.percentile(x, [75, 25]))
                bw = 0.9*min(sd, iqr/1.34)*n**-0.2                          # Silverman rule-of-thumb bandwidth
                dens = np.array([np.sum(ww*np.exp(-.5*((g - x)/bw)**2)) for g in grid])
                dens[(grid < x.min()) | (grid > x.max())] = 0
                dens = np.round(100*dens/dens.max()).astype(int).tolist()
                row.append([n, int(round(x.min())), int(round(a1)), int(round(md)), int(round(a3)), int(round(hi)), int(round(np.average(x, weights=ww)))] + dens)
            if any(row): S[f'{r}_{a}'] = row                                # skip selections with no group >= min n
    return {'L': EDU_SHORT, 'F': EDU_LEVELS, 'Y': Y, 'G': VIOLIN_GRID, 'S': S}

# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--household',  default='Egypt21_Household_Translated.xlsx')
    ap.add_argument('--individual', default='Egypt21_Individual_Translated.xlsx')
    ap.add_argument('--template',   default='dashboard_template.html')
    ap.add_argument('--out',        default='index.html')
    ap.add_argument('--dump-json',  action='store_true', help='also write the data blocks to dashboard_data.json')
    args = ap.parse_args()
    hh, ind, regions = load(args)
    blocks = {'D': build_D(hh, ind, regions), 'V': build_V(hh), 'SB': build_SB(hh, ind), 'XB': build_XB(hh, ind), 'INC': build_INC(hh)}
    html = open(args.template, encoding='utf-8').read()
    for k, v in blocks.items():
        assert html.count(f'@@{k}@@') == 1, f'placeholder @@{k}@@ missing in template'
        html = html.replace(f'@@{k}@@', json.dumps(v, separators=(',', ':'), ensure_ascii=False))
    open(args.out, 'w', encoding='utf-8').write(html)
    if args.dump_json: json.dump(blocks, open('dashboard_data.json', 'w'), ensure_ascii=False)
    print('wrote', args.out, f'({len(html)/1e3:,.0f} KB)')

if __name__ == '__main__':
    main()


