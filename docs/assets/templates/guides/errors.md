Navigation: Error Handling
SortOrder: 200

## Error handling

The unified search API supports many query string parameters.  It validates
parameters strictly - any unknown parameters, or parameters with invalid
options, will cause an HTTP 422 error.  This makes it likely that typos do not
result in silently returning the wrong results, and also makes it easier to
modify the API to add new features without risking breaking old calls.
