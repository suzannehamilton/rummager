#!/usr/bin/env python

import requests
import csv

INDEXES = ["government", "mainstream", "detailed", "service-manual"]
TERMS_FACET_QUERY = '''
{
  "size": 0,
  "facets": {
     "terms": {
        "terms": {
           "field": "lowercase_word_split_text",
           "size": 1000000
        }
     }
  }
}
'''

for index in INDEXES:
    result = requests.post(
        "http://localhost:9200/%s/_search" % (index, ),
        data=TERMS_FACET_QUERY
    )
    with open("tmp/words_%s.csv" % index, "wb+") as fobj:
        writer = csv.writer(fobj)
        writer.writerow(["word", "documents containing word"])
        for term in result.json()["facets"]["terms"]["terms"]:
            writer.writerow([
                term["term"].encode('utf8'),
                term["count"],
            ])
