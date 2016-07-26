require "logging"
require "cgi"
require "json"
require "rest-client"
require "legacy_client/client"
require "legacy_client/multivalue_converter"
require "legacy_client/scroll_enumerator"
require "legacy_search/advanced_search"
require "search/escaping"
require "search/result_set"
require "indexer"
require "indexer/amender"
require "document"
require "securerandom"

module SearchIndices
  class IndexLocked < RuntimeError; end

  class Index
    include Search::Escaping

    # The number of documents to retrieve at once when retrieving all documents
    # Gotcha: this is actually the number of documents per shard, so there will
    # be up to some multiple of this number per page.
    def self.scroll_batch_size
      50
    end

    # How long to wait between reads when streaming data from the elasticsearch server
    TIMEOUT_SECONDS = 5.0

    # How long to wait for a connection to the elasticsearch server
    OPEN_TIMEOUT_SECONDS = 5.0

    attr_reader :mappings, :index_name

    def initialize(base_uri, index_name, base_index_name, mappings, search_config)
      # Save this for if and when we want to build custom Clients
      @index_uri = base_uri + "#{CGI.escape(index_name)}/"

      @client = build_client
      @index_name = index_name
      raise ArgumentError, "Missing index_name parameter" unless @index_name
      @mappings = mappings
      @search_config = search_config
      @document_types = @search_config.schema_config.document_types(base_index_name)
      @is_content_index = !(@search_config.auxiliary_index_names.include? base_index_name)
    end

    # Translate index names like `mainstream-2015-05-06t09..` into its
    # proper name, eg. "mainstream", "government" or "service-manual".
    # The regex takes the string until the first digit. After that, strip any
    # trailing dash from the string.
    def self.strip_alias_from_index_name(aliased_index_name)
      aliased_index_name.match(%r[^\D+]).to_s.chomp('-')
    end

    def real_name
      # If the index exists, it will return something of the form:
      # { real_name => { "aliases" => { alias => {} } } }
      # If not, ES would return {} before version 0.90, but raises a 404 with version 0.90+
      begin
        alias_info = JSON.parse(@client.get("_aliases"))
      rescue RestClient::ResourceNotFound => e
        response_body = JSON.parse(e.http_body)
        if response_body['error'].start_with?("IndexMissingException")
          return nil
        end
        raise
      end

      alias_info.keys.first
    end

    def exists?
      ! real_name.nil?
    end

    def close
      @client.post("_close", nil)
    end

    # Apply a write lock to this index, making it read-only
    def lock
      request_body = { "index" => { "blocks" => { "write" => true } } }.to_json
      @client.put("_settings", request_body, content_type: :json)
    end

    # Remove any write lock applied to this index
    def unlock
      request_body = { "index" => { "blocks" => { "write" => false } } }.to_json
      @client.put("_settings", request_body, content_type: :json)
    end

    def with_lock
      logger.info "Locking #{@index_name}"
      lock
      begin
        yield
      ensure
        logger.info "Unlocking #{@index_name}"
        unlock
      end
    end

    def add(documents, options = {})
      logger.info "Adding #{documents.size} document(s) to #{index_name}"

      document_hashes = documents.map(&:elasticsearch_export)
      bulk_index(document_hashes, options)
    end

    # `bulk_index` is the only method that inserts/updates documents. The other
    # indexing-methods like `add` and `amend` eventually end up
    # calling this method.
    def bulk_index(document_hashes_or_payload, options = {})
      client = build_client(options)
      payload_generator = Indexer::BulkPayloadGenerator.new(@index_name, @search_config, @client, @is_content_index)
      response = client.post("_bulk", payload_generator.bulk_payload(document_hashes_or_payload), content_type: :json)
      items = JSON.parse(response.body)["items"]
      failed_items = items.select do |item|
        data = item["index"] || item["create"]
        data.has_key?("error")
      end

      if failed_items.any?
        # Because bulk writes return a 200 status code regardless, we need to
        # parse through the errors to detect responses that indicate a locked
        # index
        blocked_items = failed_items.select { |item|
          locked_index_error?(item["index"]["error"])
        }
        if blocked_items.any?
          raise IndexLocked
        else
          Airbrake.notify(Indexer::BulkIndexFailure.new, parameters: { failed_items: failed_items })
          raise Indexer::BulkIndexFailure
        end
      end

      response
    end

    def amend(document_id, updates)
      Indexer::Amender.new(self).amend(document_id, updates)
    end

    def get_document_by_id(document_id)
      begin
        response = @client.get("_all/#{CGI.escape(document_id)}")
        document_from_hash(JSON.parse(response.body)["_source"])
      rescue RestClient::ResourceNotFound
        nil
      end
    end

    def document_from_hash(hash)
      Document.from_hash(hash, @document_types)
    end

    def all_documents(options = nil)
      client = options ? build_client(options) : @client

      # Set off a scan query to get back a scroll ID and result count
      search_body = { query: { match_all: {} } }
      batch_size = self.class.scroll_batch_size
      LegacyClient::ScrollEnumerator.new(client, search_body, batch_size) do |hit|
        document_from_hash(hit["_source"].merge("_id" => hit["_id"]))
      end
    end

    def all_document_links(exclude_formats = [])
      search_body = {
        "query" => {
          "bool" => {
            "must_not" => {
              "terms" => {
                "format" => exclude_formats
              }
            }
          }
        },
        "fields" => ["link"]
      }

      batch_size = self.class.scroll_batch_size
      LegacyClient::ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        hit.fetch("fields", {})["link"]
      end
    end

    def documents_by_format(format, field_definitions)
      batch_size = 500
      search_body = {
        query: { term: { format: format } },
        fields: field_definitions.keys,
      }

      LegacyClient::ScrollEnumerator.new(@client, search_body, batch_size) do |hit|
        LegacyClient::MultivalueConverter.new(hit["fields"], field_definitions).converted_hash
      end
    end

    def advanced_search(params)
      LegacySearch::AdvancedSearch.new(@mappings, @document_types, @client).result_set(params)
    end

    def raw_search(payload, type = nil)
      json_payload = payload.to_json
      logger.debug "Request payload: #{json_payload}"
      if type.nil?
        path = "_search"
      else
        path = "#{type}/_search"
      end
      JSON.parse(@client.get_with_payload(path, json_payload))
    end

    # Convert a best bet query to a string formed by joining the normalised
    # words in the query with spaces.
    #
    # duplicated in document_preparer.rb
    def analyzed_best_bet_query(query)
      analyzed_query = JSON.parse(
        @client.get_with_payload("_analyze?analyzer=best_bet_stemmed_match", query)
      )

      analyzed_query["tokens"].map { |token_info|
        token_info["token"]
      }.join(" ")
    end

    def delete(type, id)
      begin
        @client.delete("#{CGI.escape(type)}/#{CGI.escape(id)}")
      rescue RestClient::ResourceNotFound
        # We are fine with trying to delete deleted documents.
        true
      rescue RestClient::Forbidden => e
        response_body = JSON.parse(e.http_body)
        if locked_index_error?(response_body["error"])
          raise IndexLocked
        else
          raise
        end
      end

      true # For consistency with the Solr API and simple_json_response
    end

    def commit
      @client.post "_refresh", nil
    end

    def register_percolation_query(query, uuid: SecureRandom.uuid)
      percolation_query = {}
      matches = query["matches"] || {}
      filters = query["filters"] || {}
      ranges = query["ranges"] || {}

      if matches.any?
        percolation_query["match"] = matches
      end

      if ranges.any?
        percolation_query["range"] = ranges.each_with_object({}) { |(field, extents), hash|
          es_range = {}
          es_range["gt"] = extents["after"] unless extents["after"].blank?
          es_range["lt"] = extents["before"] unless extents["before"].blank?

          hash[field] = es_range
        }
      end

      if percolation_query.empty?
        percolation_query["match_all"] = {}
      end

      if filters.any?
        es_filters ||= {
          "and" => []
        }

        filters.each do |(field, values)|
          Array(values).each do |value|
            es_filters["and"] << {
              "term" => {
                field => value
              }
            }
          end
        end

        percolation_query = {
          "filtered" => {
            "query" => percolation_query,
            "filter" => es_filters,
          }
        }
      end

      es_query = {
        "query" => percolation_query,
        "type" => "edition",
      }.merge(filters)

      puts "Registering #{es_query}"
      puts

      @client.post(".percolator/#{uuid}", es_query.to_json, content_type: :json)
    end

    def percolate(doc)
      links = doc["links"] || {}
      facets = doc.slice(
        "document_type",
        "schema_name",
      )

      # doc["details"].each do |key, value|
      #   doc["details.#{key}"] = value
      # end

      es_query = {
        doc: doc.merge(links),
      }

      if facets.any? || links.any?
        es_query[:filter] ||= {
          or: []
        }

        facets.each do |(field, value)|
          es_query[:filter][:or] << {
            term: {
              field => value
            }
          }
        end

        links.each do |(field, values)|
          es_query[:filter][:or] << {
            terms: {
              field => values
            }
          }
        end
      end

      json_result = @client.post("edition/_percolate", es_query.to_json)
      puts "Percolating #{es_query}"
      puts "Result #{JSON.parse(json_result)}"
      puts
      JSON.parse(json_result)
    end

    def link_to_type_and_id(link)
      # If link starts with edition/ or best-bet/ then use those values for the
      # type.  For backwards compact, if it starts with anything else currently
      # assume that the type is edition.
      if (m = link.match(/\A(edition|best_bet)\/(.*)\Z/))
        return [m[1], m[2]]
      else
        return ["edition", link]
      end
    end

    def self.index_recovered?(base_uri:, index_name:)
      # Check if an index has recovered all its shards.
      # https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-recovery.html
      # If something goes wrong, a shard can get stuck and not reach the DONE state.
      client = Elasticsearch::Client.new(host: base_uri).indices
      index_info = client.recovery(index: index_name)[index_name]
      index_info["shards"].all? { |shard_info| shard_info["stage"] == "DONE" }
    end

  private

    # Parse an elasticsearch error message to determine whether it's caused by
    # a write-locked index. An example write-lock error message:
    #
    #     "ClusterBlockException[blocked by: [FORBIDDEN/8/index write (api)];]"
    def locked_index_error?(error_message)
      error_message =~ %r{\[FORBIDDEN/[^/]+/index write}
    end

    def logger
      Logging.logger[self]
    end

    def build_client(options = {})
      LegacyClient::Client.new(
        @index_uri,
        timeout: options[:timeout] || TIMEOUT_SECONDS,
        open_timeout: options[:open_timeout] || OPEN_TIMEOUT_SECONDS
      )
    end
  end
end
