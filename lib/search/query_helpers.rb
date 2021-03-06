module Search
  # Mixin for building elasticsearch queries
  module QueryHelpers
  private

    # Combine filters using an operator
    #
    # `filters` should be a sequence of filters. nil filters are ignored.
    # `op` should be :and or :or
    #
    # If 0 non-nil filters are supplied, returns nil.  Otherwise returns the
    # elasticsearch query required to match the filters
    def combine_filters(filters, op)
      filters = filters.compact
      if filters.empty?
        nil
      elsif filters.length == 1
        filters.first
      else
        { op => filters }
      end
    end

    def terms_filter(field_name, values)
      return nil if values.empty?

      { "terms" => { field_name => values } }
    end

    def term_filter(field_name, value)
      { "term" => { field_name => value } }
    end

    def date_filter(field_name, value)
      {
        "range" => {
          field_name => {
            "from" => value["from"].iso8601,
            "to" => value["to"].iso8601,
          }.reject { |_, v| v.nil? }
        }
      }
    end

    def dis_max_query(queries, tie_breaker: 0.0, boost: 1.0)
      # Calculates a score by running all the queries, and taking the maximum.
      # Adds in the scores for the other queries multiplied by `tie_breaker`.
      if queries.size == 1
        queries.first
      else
        {
          dis_max: {
            queries: queries,
            tie_breaker: tie_breaker,
            boost: boost,
          }
        }
      end
    end
  end
end
