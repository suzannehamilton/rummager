require 'search/query_helpers'

module QueryComponents
  class UserFilter < BaseComponent
    include Search::QueryHelpers

    attr_reader :rejects, :filters

    def initialize(search_params = QueryParameters.new)
      super

      @rejects = []
      @filters = []

      search_params.filters.each do |filter|
        if filter.reject
          @rejects << filter
        else
          @filters << filter
        end
      end
    end

    def selected_queries(excluding = [])
      remaining = exclude_fields_from_filters(excluding, filters)
      remaining.map { |filter| filter_hash(filter) }
    end

    def rejected_queries(excluding = [])
      remaining = exclude_fields_from_filters(excluding, rejects)
      remaining.map { |filter| filter_hash(filter) }
    end

  private

    def filter_hash(filter)
      es_filters = []

      if filter.include_missing
        es_filters << { "missing" => { field: filter.field_name } }
      end

      field_name = filter.field_name
      values = filter.values

      case filter.type
      when "string"
        es_filters << terms_filter(field_name, values)
      when "boolean"
        es_filters << terms_filter(field_name, values)
      when "date"
        es_filters << date_filter(field_name, values.first)
      else
        raise "Filter type not supported"
      end

      combine_filters(es_filters, :or)
    end

    def exclude_fields_from_filters(excluded_field_names, filters)
      filters.reject do |filter|
        excluded_field_names.include?(filter.field_name)
      end
    end
  end
end
