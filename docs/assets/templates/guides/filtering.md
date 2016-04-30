Navigation: Filtering
SortOrder: 400

## Filtering

 - `filter_FIELD`: (single string, where `FIELD` is a field name); a filter to
   apply to a field.

   Multiple values may be given, and filters may be specified for multiple
   fields at once.  The filters are grouped by field name; documents will only
   be returned if they match all of these filter groups, and they will be
   considered to match a filter group if any of the individual filters in that
   group match (ie, only one of the values specified for a field needs to
   match, but all fields with any filters specified must match at least one
   value).

   The special value `_MISSING` may be specified as a filter value - this will
   match documents where the field is not present at all.

   For string fields, values are the field value to match.

   For date fields, values are date ranges.  These are specified as comma
   separated lists of `key:value` parameters, where `key` is one of `from` or
   `to`, and the value is an ISO formatted date (with no timezone).  UTC is
   assumed for all dates handled by rummager.  Date ranges are inclusive of
   their endpoints.

   For example: `from:2014-04-01 00:00,to:2014-04-02 00:00` is a range for 24
   hours from midnight at the start of April the 1st 2014, including midnight
   that day or the following day.

   Currently, it is not permitted to specify multiple values for a date field
   filter.

   Only some fields can be filtered on - an HTTP 422 error will be returned if
   the requested field is not a value sort field.

 - `reject_FIELD`: (single string where `FIELD` is a field name); a
   reject-filter to apply to a field.  This behaves just like a filter, but
   will return documents which don't match any of the supplied values for a
   field.

   If a filter and a reject are specified for the same field, an HTTP 422 error
   will be returned.  However, it is valid to specify a reject for some fields
   and a filter for others - documents will be required to match the criteria
   on both fields.


