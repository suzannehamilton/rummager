Navigation: Faceting
SortOrder: 500

## Faceting

 - `facet_FIELD`: (single string where `FIELD` is a field name); count up
   values which are present in the field in the documents matched by the
   search, and return information about these.

   The value of this parameter is a comma separated list of options; the first
   option in the list is an integer which controls the requested number of
   distinct field values to be returned for the field.  Regardless of the
   number set here, a value will be returned for any filter which is in place
   on the field. This may cause the requested number of values to be exceeded.

   Subsequent options are optional, and are represented as colon separated
   key:value pairs (note, colon separated instead of comma, since commas are
   used to separate options).

   - `scope`: One of `all_filters` and `exclude_field_filter` (the default).

     If set to `all_filters`, the facet counts are made after applying all the
     filters.  If set to `exclude_field_filter`, the facet counts are made
     after applying all filters _except_ for those applied to the field that
     the facets are being counted for.  This is a convenient option for
     calculating values to show in common interfaces which use facets for
     narrowing down search results.

   - `order`: Colon separated list of ordering types.

     The available ordering types are:

      - `filtered`: whether the value is used in an active filter.  This can be
	used to sort such that the values which are being filtered on come
	first.
      - `count`: order by the number of documents in the search matching the
	facet value.
      - `value`: sort by value if the field values are string, sort by the
	`title` field in the value object if the value is an object.  Sorting
	is case insensitive in either case.
      - `value.slug`: the slug in the facet value object
      - `value.link`: the link in the facet value object
      - `value.title`: the title in the facet value object (case insensitive)

     Each ordering may be preceded by a "-" to sort in descending order.
     Multiple orderings can be specified, in priority order, separated by a
     colon.  The default ordering is "filtered:-count:slug".

   - `examples`: integer number of example values to return

     This causes facet values to contain an "examples" hash as an additional
     field, which contains details of example documents which match the query.
     The examples are sorted by decreasing popularity.  An example facet value
     in a response with this option set as "examples:1" might look like:

        "value" => {
          "slug" => "an-example-facet-slug",
          "example_info" => {
            "total" => 3,  # The total number of matching examples
            "examples" => [
              {"title" => "Title of the first example", "link" => "/foo"},
            ],
          }
        }

   - `example_scope`: `global` or `query`.  If the `examples` option is supplied, the
     `example_scope` option must be supplied too.

     The value of `global` causes the returned examples to be taken from all
     documents in which the facet field has the given slug.

     The value of `query` causes the returned examples to be taken only from
     those documents which match the query (and all filters).

   - `example_fields`: colon separated list of fields.

     If the examples option is supplied, this lists the fields which are
     returned for each example.  By default, only a small number of fields are
     returned for each.

 - fields: fields to be returned in the result documents.  By default, and for
   backwards compatibility, a fairly long set of fields is currently returned,
   but it is good practice to set this to only the fields you actually want
   information on (doing this will normally increase performance).
