# Decision record: Decouple read and write aliases

Date: 2017-08-23

## Context
### Moving to a publishing-api derived index
We're currently replacing older indexes derived from individual
publishing apps, with a single index (`govuk`), derived from Publishing API.

There is a mechanism in place for rebuilding the search index to reindex the content
after changing the mappings. This is something we need to do after adding new fields
for them to work properly.

There is also a mechanism for keeping the popularity field up to date every night.
Since [ADR 003: Popularity updating without index locks](adr-003-popularity-updating-without-index-locks.md),
this uses updates, rather than rebuilding the search index.

Note that both of these mechanisms do not add or remove documents from the search index.

We'd like to be able to refetch existing content from the source (Publishing API)
in bulk, and index it into Elasticsearch.

- This is something we need to do to initially populate the `govuk` index.
- If we make this process easy to rerun, we have the option of recreating the index at any time
if data is lost or corrupted, making search unusable.
- If we run this process regularly, we can ensure that Elasticsearch stays in sync with Publishing API,
rather than diverging over time, and we test that the process works.

### Use of aliases
Rummager currently reads from Elasticsearch aliases rather than using indexes directly.

An alias (such as `mainstream`) points to a corresponding index with
a timestamp in the name (such as `mainstream-2017-08-18t14:33:23z-00000000-0000-0000-0000-000000000000`).

Using this, we can peform the [Zero Downtime Index Shuffle](https://www.elastic.co/guide/en/elasticsearch/guide/current/index-aliases.html) to rebuild an index without downtime to the search API. This involves the following steps:

1. lock the existing index to new writes
2. populate a brand new index with a new name
3. switch the alias to the new index

### Questions addressed in this ADR
1. When we bulk-reindex content from the publishing API, should we create a new
index or not?

2. How do we carry out the bulk-reindex without affecting the search API?

### Questions not addressed
Publishing API data could be pulled into Rummager via the API, or pushed
through the message queue. Our working assumption is that we'll use the
message queue, but this ADR should be agnostic to the approach taken.

## Decision

### Proposal 1: Design the reindex process with a complete index rebuild in mind
We don't need to build a fresh index to achieve our immediate goal of populating
the new index.

But: doing so means we can recreate the thing from scratch, instead of
preserving old data, regardless of whether it's actually supposed to be there.

### Proposal 2: Introduce a separate alias
The existing alias `govuk` can be used by the Search API for reading.

The new alias `govuk-bulk-write-index` can be used for bulk writing.

When `govuk-bulk-write-index` points to the current index, Rummager will
index over the top of the existing day.

When we want to populate the new index from scratch, we can keep the bulk
reindex process working as before, but add some coordinating tasks around it.

The steps would look something like:

1. Lock old index for writing
2. Create a new index
3. Point `govuk-bulk-write-index` to it
4. Trigger the bulk reindex process
5. Wait for the process to end (????)
6. Point `govuk` to it

## Consequences

Consequences here...
