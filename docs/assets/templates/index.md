Navigation: Introduction
SortOrder: 100

## Rummager Search API

This API is the main endpoint for performing searches on GOV.UK.  It supports
keyword searching, ordering by relevance or date fields, filtering and
faceting.

At the time of writing, there is one other endpoint, the `advanced_search`
endpoint, which is slowly being replaced by the `unified_search` endpoint.  The
`advanced_search` endpoint shouldn't be used by new code.

### Quickstart

The user entered search query is specified using the `q` parameter:.  This should be exactly what the user typed into a search box, encoded as `UTF-8`.  Any well-formed `UTF-8` values are allowed.  Lots of complex processing will be performed on this field to try to determine the best matching documents for the query.

#### Using the [GDS API Adapters](https://github.com/alphagov/gds-api-adapters)

```
require 'gds_api/rummager'
rummager = GdsApi::Rummager.new(Plek.new.find('rummager'))
results = rummager.unified_search(q: "taxes")
```

#### Using the public search endpoint

```
curl -X GET https://www.gov.uk/api/search.json?q=taxes
```
