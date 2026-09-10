"""Replica of GillianCore/smt/CertifiedSMT.ml's coerce_* over the corpus JSON,
collecting EVERY blocking feature per query rather than the first."""
import json, sys, itertools, collections

CORPUS = '/Users/st621/dev/Gillian/experiments/certified-smt.jsonl'

UNOP_OK  = {'Not', 'LstLen', 'IsInt', 'NumToInt', 'IntToNum'}
BINOP_OK = {'Equal','ILessThan','IPlus','IMinus','ITimes','IDiv','IMod',
            'FPlus','FMinus','FTimes','FDiv','FLessThan','FLessThanEqual','And',
            'LstNth'}
NOP_OK   = {'LstCat'}
TYPE_OK  = {'NullType','NoneType','EmptyType','BooleanType','IntType',
            'NumberType','StringType','ListType','ObjectType'}
LIT_OK   = {'Null','Nono','Empty','Loc','Bool','Int','Num','String'}  # LList handled

def type_blockers(ty):
    t = ty[0]
    return set() if t in TYPE_OK else {'type:'+t}

def lit_blockers(l):
    t = l[0]
    if t == 'LList':
        return set().union(set(), *[lit_blockers(x) for x in l[1]]) if l[1] else set()
    if t == 'Num':
        import math
        v = l[1]
        if isinstance(v, str):            # nan / inf serialise as strings
            return {'lit:Num-nonfinite'}
        if not math.isfinite(v):
            return {'lit:Num-nonfinite'}
        return set()
    if t in LIT_OK:
        return set()
    return {'lit:'+t}

def blockers(e):
    """Every feature that makes coerce_symbexp return None, as a set of tokens."""
    t = e[0]
    if t == 'Lit':
        return lit_blockers(e[1])
    if t in ('LVar','ALoc'):
        return set()
    if t == 'PVar':
        return {'expr:PVar'}
    if t == 'UnOp':
        op = e[1][0]; sub = e[2]
        if op in ('FUnaryMinus','IUnaryMinus'):     # lowered to 0 - e
            return blockers(sub)
        b = blockers(sub)
        if op not in UNOP_OK:
            b = b | {'unop:'+op}
        return b
    if t == 'BinOp':
        e1, op, e2 = e[1], e[2][0], e[3]
        # TypeOf(e) == Lit (Type t)
        if (e1[0] == 'UnOp' and e1[1][0] == 'TypeOf'
                and op == 'Equal' and e2[0] == 'Lit' and e2[1][0] == 'Type'):
            return blockers(e1[2]) | type_blockers(e2[1][1])
        if op in BINOP_OK:
            return blockers(e1) | blockers(e2)
        if op == 'ILessThanEqual':
            return blockers(['BinOp',['BinOp',e1,['ILessThan'],e2],['Or'],
                                     ['BinOp',e1,['Equal'],e2]])
        if op == 'Or':
            return blockers(e1) | blockers(e2)
        if op == 'Impl':
            return blockers(['BinOp',['UnOp',['Not'],e1],['Or'],e2])
        return blockers(e1) | blockers(e2) | {'binop:'+op}
    if t == 'EList':
        return set().union(set(), *[blockers(x) for x in e[1]]) if e[1] else set()
    if t == 'ESet':
        return {'expr:ESet'} | (set().union(set(), *[blockers(x) for x in e[1]]) if e[1] else set())
    if t == 'LstSub':
        return {'expr:LstSub'} | blockers(e[1]) | blockers(e[2]) | blockers(e[3])
    if t == 'NOp':
        inner = set().union(set(), *[blockers(x) for x in e[2]]) if e[2] else set()
        return inner if e[1][0] in NOP_OK else {'nop:'+e[1][0]} | inner
    if t == 'Exists':
        return {'expr:Exists'} | blockers(e[2])
    if t == 'ForAll':
        return {'expr:ForAll'} | blockers(e[2])
    return {'expr:UNKNOWN-'+t}

def lvars(e):
    """Names that end up as Symbexp.LVar in the coerced tree (LVar + ALoc)."""
    t = e[0]
    if t == 'LVar' or t == 'ALoc':
        return {e[1]}
    out = set()
    for x in e[1:]:
        if isinstance(x, list):
            if x and isinstance(x[0], str) and x[0] in (
                'Lit','LVar','ALoc','PVar','UnOp','BinOp','EList','ESet',
                'LstSub','NOp','Exists','ForAll'):
                out |= lvars(x)
            else:
                for y in x:
                    if isinstance(y, list) and y and isinstance(y[0], str):
                        out |= lvars(y)
    return out

records = []
with open(CORPUS) as f:
    for line in f:
        r = json.loads(line)
        b = set()
        vs = set()
        for e in r['expressions']:
            b |= blockers(e)
            vs |= lvars(e)
        gamma = dict((k, v) for k, v in r['gamma'])
        for v in sorted(vs):
            if v in gamma:
                b |= type_blockers(gamma[v])
        records.append({'blockers': b, 'coerced': r['verified']['coerced'],
                        'sat_v': r['verified']['sat_result'],
                        'sat_u': r['unverified']['sat_result'],
                        'exprs': r['expressions'],
                        'argv': r['argv']})

N = len(records)
# --- validation ---
mismatch = [(i, r) for i, r in enumerate(records) if (not r['blockers']) != r['coerced']]
print(f'records: {N}')
print(f'recorded coerced: {sum(r["coerced"] for r in records)}')
print(f'replica coerced : {sum(1 for r in records if not r["blockers"])}')
print(f'MISMATCHES      : {len(mismatch)}')
for i, r in mismatch[:8]:
    print('  #%d recorded=%s blockers=%s' % (i, r['coerced'], sorted(r['blockers'])))

# Every operator the plan may add, with the blocker token it emits.  A
# candidate drops out of the report once its coerce_* arm lands, because the
# replica then stops emitting its token at all.
ALL_CANDIDATES = {
    'as_int': 'unop:NumToInt', 'is_int': 'unop:IsInt', 'as_num': 'unop:IntToNum',
    'int*': 'binop:ITimes', 'real*': 'binop:FTimes',
    'LstNth': 'binop:LstNth', 'LstCat': 'nop:LstCat',
}
seen = set().union(set(), *[r['blockers'] for r in records])
CANDIDATES = {k: v for k, v in ALL_CANDIDATES.items() if v in seen}

def cov(ext):
    """number of queries that coerce when the tokens in `ext` are supported"""
    return sum(1 for r in records if r['blockers'] <= ext)

base = cov(set())
EXT = set(CANDIDATES.values())
allf = cov(EXT)
print()
print(f'baseline           : {base}/{N} ({100*base/N:.1f}%)')
print(f'with all candidates: {allf}/{N} ({100*allf/N:.1f}%)  delta +{allf-base}')
print()
print('--- each candidate alone ---')
for k, v in CANDIDATES.items():
    c = cov({v})
    print(f'  {k:7s} {c:5d}  (+{c-base})')
print()
print('--- greedy addition order ---')
have, cur = set(), base
for _ in range(len(CANDIDATES)):
    best = max(((k, cov(have | {v})) for k, v in CANDIDATES.items()
                if v not in have),
               key=lambda p: p[1])
    k, c = best
    have |= {CANDIDATES[k]}
    print(f'  +{k:7s} -> {c:5d} ({100*c/N:.1f}%)  marginal +{c-cur}')
    cur = c
print()
print('--- every subset of the candidates ---')
items = list(CANDIDATES.items())
rows = []
for n in range(len(items) + 1):
    for combo in itertools.combinations(items, n):
        ext = {v for _, v in combo}
        rows.append((n, cov(ext), '+'.join(k for k, _ in combo) or '(none)'))
for n, c, name in sorted(rows, key=lambda t: (t[0], -t[1])):
    print(f'  {n}  {c:5d} ({100*c/N:4.1f}%)  {name}')

rest = [r for r in records if not (r['blockers'] <= EXT)]
print()
print(f'--- residual blockers among the {len(rest)} still blocked with all candidates ---')
freq = collections.Counter()
solo = collections.Counter()
for r in rest:
    b = r['blockers'] - EXT
    freq.update(b)
    if len(b) == 1:
        solo[next(iter(b))] += 1
print(f'  still blocked: {len(rest)}')
for k, c in freq.most_common():
    print(f'  {k:22s} appears in {c:5d}   sole remaining blocker in {solo.get(k,0):5d}')
print()
print('--- next single target on top of the candidates ---')
for k in freq:
    c = cov(EXT | {k})
    print(f'  +{k:22s} -> {c:5d} ({100*c/N:.1f}%)  marginal +{c-allf}')

def lits_of(e, out):
    if e[0] == 'Lit':
        def go(l):
            if l[0] == 'LList':
                for x in l[1]: go(x)
            else: out.append(l)
        go(e[1]); return
    for x in e[1:]:
        if isinstance(x, list):
            if x and isinstance(x[0], str) and x[0] in (
              'Lit','LVar','ALoc','PVar','UnOp','BinOp','EList','ESet','LstSub','NOp','Exists','ForAll'):
                lits_of(x, out)
            else:
                for y in x:
                    if isinstance(y, list) and y and isinstance(y[0], str): lits_of(y, out)

def numeric_profile(rs, label):
    nz = nn = negint = zint = 0
    for r in rs:
        ls = []
        for e in r['exprs']: lits_of(e, ls)
        nums = [l[1] for l in ls if l[0] == 'Num']
        ints = [int(l[1]) for l in ls if l[0] == 'Int']
        if any(isinstance(v,(int,float)) and v == 0 for v in nums): nz += 1
        if any(isinstance(v,(int,float)) and v < 0 for v in nums): nn += 1
        if any(v < 0 for v in ints): negint += 1
        if any(v == 0 for v in ints): zint += 1
    print(f'{label} (n={len(rs)}):')
    print(f'   Num literal == 0        : {nz} ({100*nz/max(1,len(rs)):.1f}%)')
    print(f'   Num literal <  0        : {nn} ({100*nn/max(1,len(rs)):.1f}%)')
    print(f'   Num <= 0 (either)       : {sum(1 for r in rs for _ in [0] if True and False) or "-"}')
    print(f'   Int literal <  0        : {negint}')
    print(f'   Int literal == 0        : {zint}')

print()
print('=== numeric-literal profile (the Qp / unsigned-nat gap) ===')
coerced_now = [r for r in records if not r['blockers']]
coerced_five = [r for r in records if r['blockers'] <= EXT]
numeric_profile(coerced_now,  'coerced today')
numeric_profile(coerced_five, 'coerced with all candidates')

def nonpos_num(r):
    ls = []
    for e in r['exprs']: lits_of(e, ls)
    return any(isinstance(l[1],(int,float)) and l[1] <= 0 for l in ls if l[0]=='Num')
print()
print(f'coerced today with a Num <= 0 : {sum(1 for r in coerced_now if nonpos_num(r))}')
print(f'coerced+cands with a Num <= 0 : {sum(1 for r in coerced_five if nonpos_num(r))}')

print()
print('=== sat agreement on the queries that reach the verified encoder today ===')
ag = collections.Counter()
for r in coerced_now:
    ag[(r['sat_u'], r['sat_v'])] += 1
for k, v in ag.most_common(): print('  unverified=%s verified=%s : %d' % (k[0], k[1], v))

def mentions(e, tag, kind):
    if e[0] == kind == 'UnOp' and e[1][0] == tag: return True
    if e[0] == kind == 'BinOp' and e[2][0] == tag: return True
    if e[0] == kind == 'NOp' and e[1][0] == tag: return True
    for x in e[1:]:
        if isinstance(x, list):
            if x and isinstance(x[0], str) and x[0] in (
              'Lit','LVar','ALoc','PVar','UnOp','BinOp','EList','ESet','LstSub','NOp','Exists','ForAll'):
                if mentions(x, tag, kind): return True
            else:
                for y in x:
                    if isinstance(y, list) and y and isinstance(y[0],str) and mentions(y, tag, kind): return True
    return False

print()
print(f'=== how many of the {len(coerced_five)} reachable queries mention each op ===')
for tag, kind, name in [('IntToNum','UnOp','as_num'), ('NumToInt','UnOp','as_int'),
                        ('IsInt','UnOp','is_int'), ('ITimes','BinOp','int*'),
                        ('FTimes','BinOp','real*'), ('LstNth','BinOp','LstNth'),
                        ('LstCat','NOp','LstCat')]:
    c = sum(1 for r in coerced_five if any(mentions(e, tag, kind) for e in r['exprs']))
    cn = sum(1 for r in coerced_now if any(mentions(e, tag, kind) for e in r['exprs']))
    print(f'  {name:7s} {c:5d} of {len(coerced_five)}   (of which {cn} coerce today)')
