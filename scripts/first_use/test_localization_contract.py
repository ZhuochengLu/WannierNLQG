#!/usr/bin/env python3
"""Reject numeric and metadata tampering in the original localization contract."""
import copy
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from localization_campaign import ROOT, scientific_fields, checkpoint_fields


def main():
    contract = json.loads((ROOT/'test/fixtures/first_use_science/localization_contract.json').read_text())
    summary = {'leaves':list(contract['scientific_return_fields'].values())}
    native = {'fields':list(contract['scientific_checkpoint_fields'].values()),
              'official_integrity_reader_verified':True}
    assert scientific_fields(summary,contract['excluded_return_fields']) == contract['scientific_return_fields']
    assert checkpoint_fields(native,contract) == contract['scientific_checkpoint_fields']
    rejected = []
    def reject(label, change, *, checkpoint=True):
        data = copy.deepcopy(native if checkpoint else summary)
        proof = copy.deepcopy(contract)
        change(data,proof)
        try:
            result = checkpoint_fields(data,proof) if checkpoint else scientific_fields(data,proof['excluded_return_fields'])
        except ValueError:
            rejected.append(label)
        else:
            expected = contract['scientific_checkpoint_fields'] if checkpoint else contract['scientific_return_fields']
            assert result != expected, label
            rejected.append(label)
    reject('return missing field',lambda d,p:d['leaves'].pop(),checkpoint=False)
    reject('return duplicate field',lambda d,p:d['leaves'].append(d['leaves'][0]),checkpoint=False)
    reject('return arbitrary exclusion',lambda d,p:p['excluded_return_fields'].append(d['leaves'][0]['path']),checkpoint=False)
    reject('return scientific value',lambda d,p:d['leaves'][0].update(value='changed'),checkpoint=False)
    reject('checkpoint missing field',lambda d,p:d['fields'].pop())
    reject('checkpoint duplicate field',lambda d,p:d['fields'].append(d['fields'][0]))
    reject('checkpoint bit digest',lambda d,p:next(x for x in d['fields'] if x['kind']=='bits').update(bit_sha256='changed'))
    reject('checkpoint shape',lambda d,p:next(x for x in d['fields'] if x['kind']=='bits').update(shape=[999]))
    reject('checkpoint scientific metadata',lambda d,p:next(x for x in d['fields'] if x['kind']=='metadata').update(value='changed'))
    reject('checkpoint official reader',lambda d,p:d.update(official_integrity_reader_verified=False))
    reject('checkpoint arbitrary exclusion',lambda d,p:p['excluded_checkpoint_fields'].append(d['fields'][0]['path']))
    print(json.dumps(dict(original_scientific_return_fields=435,original_checkpoint_fields=581,
                          negatives=rejected,actual_solver_executed=False,final_pass=False),sort_keys=True))


if __name__=='__main__':
    main()
