require 'app'

class SwaggerSpec
  # TODO: refactor code in SearchParameterParser to use this constant.
  ALLOWED_DEBUG_VALUES = %w[disable_best_bets disable_popularity disable_synonyms
                            new_weighting explain]

  def initialize(schema)
    @schema = schema
  end

  def docs
    {
      swagger: '2.0',
      info: {
        title: "GOV.UK Search",
        description: "Search API for GOV.UK",
        version: "1.0.0",
      },
      host: 'www.gov.uk',
      schemes: ['https'],
      basePath: "/api",
      produces: ['application/json'],
      paths: {
        '/search.json' => {
          get: {
            summary: 'Do a search',
            parameters: parameters
          }
        }
      }
    }
  end

private

  def parameters
    (core_args + possible_filters).map { |e| e.merge(in: "query") }
  end

  def core_args
    [
      {
        name: "q",
        type: "string",
        description: "Text to search for",
      },
      {
        name: "count",
        type: "number",
        description: "Number of documents to retrieve",
      },
      {
        type: "integer",
        name: "start",
        description: "Position in search result list to start returning results (0-based)"
      },
      {
        type: "string",
        name: "order",
        description: "The sort order. A fieldname, with an optional preceding '-' to sort in descending order. If not specified, sort order is relevance",
        enum: BaseParameterParser::ALLOWED_SORT_FIELDS.sort
      },
      {
        type: "array",
        name: "fields",
        description: "Fields to return",
        default: BaseParameterParser::DEFAULT_RETURN_FIELDS.sort,
        enum: @schema.field_definitions.keys.sort
      },
      {
        type: "array",
        name: "debug",
        description: "Debug flags",
        default: [],
        enum: ALLOWED_DEBUG_VALUES.sort
      },
    ]
  end

  def possible_filters
    @schema.field_definitions.map do |name, defo|
      next unless defo.type.filter_type
      type = defo.type.filter_type == 'date' ? 'date' : 'string'

      {
        type: type,
        name: "filter_#{name}",
        description: defo.description,
      }
    end.compact
  end
end

desc "Generate a swagger definition. Experimental."
task :swagger do
  unified_index_schema = CombinedIndexSchema.new(
    Rummager.settings.search_config.content_index_names,
    Rummager.settings.search_config.schema_config
  )

  docs = SwaggerSpec.new(unified_index_schema).docs
  puts JSON.pretty_generate(docs)
end
