require 'app'
require 'swagger/blocks'

class SwaggerSpec
  include Swagger::Blocks

  # TODO: refactor code in SearchParameterParser to use this constant.
  ALLOWED_DEBUG_VALUES = %w[disable_best_bets disable_popularity disable_synonyms
                            new_weighting explain]

  def self.content_index_names
    Rummager.settings.search_config.content_index_names
  end

  def self.schema_config
    @schema_config ||= Rummager.settings.search_config.schema_config
  end

  def self.document_types
      @config ||= begin
          self.schema_config.document_types('government')
            .merge(self.schema_config.document_types('mainstream'))
            .merge(self.schema_config.document_types('detailed'))
            .merge(self.schema_config.document_types('service-manual'))
      end
  end

  def self.success_response(op)
      op.response 200, description: "Success response" do
          schema do
              key :title, "Search results"
              property :results, type: :array, items: {'$ref' => "#/definitions/document"}
              property :total, type: :integer
              property :start, type: :integer
              property :facets, type: :array, items: {'$ref' => "#/definitions/facet_result"}

              property :suggested_queries, type: :array,
                  items: {'$ref' => "#/definitions/suggestion"}
          end
      end
  end

  def self.core_args(op)
      op.parameter name: :q, type: :string, in: :query,
          description: "Text to search for"

      op.parameter name: :count, type: :number, in: :query,
          description: "Number of documents to retrieve"

      op.parameter name: :start, type: :integer, in: :query,
          description: "Position in search result list to start returning results (0-based)"

      op.parameter name: :order, type: :string, in: :query,
          description: "The sort order. A fieldname, with an optional preceding '-' to sort in descending order. If not specified, sort order is relevance",
          enum: BaseParameterParser::ALLOWED_SORT_FIELDS.sort

      op.parameter name: :fields, type: :array, in: :query, items: {type: :string},
        description: "Fields to return",
        default: BaseParameterParser::DEFAULT_RETURN_FIELDS.sort
        #enum: self.schema_config.field_definitions.keys.sort

      op.parameter name: :debug, type: :array, in: :query, items: {type: :string},
          description: "Debug flags",
          default: []
          #enum: ALLOWED_DEBUG_VALUES.sort
  end

  def self.possible_filters(op)
    schema_config.field_definitions.each do |name, defo|
      next unless defo.type.filter_type
      format = defo.type.filter_type == 'date' ? 'date' : 'string'

      op.parameter name: "filter_#{name}", in: :query,
        type: "string",
        format: format,
        description: "Include documents with this #{name} value"

      op.parameter name: "reject_#{name}", in: :query,
        type: "string",
        format: format,
        description: "Exclude documents with this #{name} value"
    end
  end

  SwaggerSpec.document_types.each do |name, document_type|
      # TODO parse types, children
      # handle entity expansion etc
      # handle array types (see result presenter)
      $stderr.puts "Generating definition for #{name}"
      swagger_schema name do
          key :title, name
          allOf do
            schema '$ref' => "#/definitions/document"

            schema do
              document_type.fields.values.each do |field|
                property field.name, type: :string, description: field.description
              end
            end
          end
      end
  end

  swagger_schema :document do
    key :required, [:document_type, :es_score, :_id, :_link, :index]
    key :discriminator, :document_type
    key :title, "Document"

    property :document_type, type: :string
    property :es_score, type: :number
    property :_id, type: :string
    property :_link, type: :string
    property :_explanation, type: :object
    property :index, type: :string
    property :title_with_highlighting, type: :string
    property :description_with_highlighting, type: :string
  end

  swagger_schema :option do
    key :title, "Option"
    property :value, type: :object do
        property :slug, type: :string
    end
  end

  swagger_schema :facet_result do
      key :title, "Facet result"
      property :options, type: :array, items: {"$ref" => "#/definitions/option"}
      property :documents_with_no_value, type: :integer
      property :total_options, type: :integer
      property :missing_options, type: :integer
      property :scope, type: :string, enum: ["exclude_field_filter", "all_filters"]
  end

  swagger_schema :suggestion, type: :array, items: {type: :string}, title: "Suggestion"

  swagger_root swagger: '2.0',
               host: 'www.gov.uk',
               schemes: ['https'],
               basePath: '/api',
               produces: ['application/json'] do

      info version: '1.0.0',
           description: "Search API for GOV.UK",
           title: "Rummager"
  end

  swagger_path '/search.json' do
      operation :get, description: 'Search Gov.uk', summary: "Search" do

          SwaggerSpec.success_response(self)
          SwaggerSpec.core_args(self)
          SwaggerSpec.possible_filters(self)
      end
  end
end

desc "Generate a swagger definition. Experimental."
task :swagger do
  puts JSON.pretty_generate(Swagger::Blocks.build_root_json([SwaggerSpec]))
end
