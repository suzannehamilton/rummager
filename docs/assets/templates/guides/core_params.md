Navigation: Query Parameters
SortOrder: 210

## Multi-valued parameters

Query parameters which are repeated may be specified in standard HTTP
style (ie, `name=value&name=value`, where the same name may be used multiple
times), or in Ruby/PHP array style (ie, `name[]=value&name[]=value`).  The `[]`
is simply ignored. This allows for easy calling from Ruby-style frameworks, or
from other languages which use standard HTTP conventions.  No more complex
structures are passed in the API.

## Pagination

Pagination can be controlled using these parameters:

  - `start`: (single integer) Position in search result list to start returning
   results (0-based)  If the `start` offset is greater than the number of
   matching results, no results will be returned (but also no error will be
   returned).

 - `count`: (single integer) Maximum number of search results to return.  If
   insufficient documents match, as many as possible are returned (subject to
   the supplied `start` offset).  This may be set to 0 to return no results
   (which may be useful if only, say, facet values are wanted).  Setting this
   to 0 will reduce processing time.

 - `order`: (single string) The sort order.  A field name, with an optional
   preceding "`-`" to sort in descending order.  If not specified, sort order
   is relevance.  Only some fields can be sorted on - an HTTP 422 error will be
   returned if the requested field is not a valid sort field.
