require "logging"
require "json"
require "legacy_client/multivalue_converter"
require "legacy_client/scroll_enumerator"
require "legacy_search/advanced_search"
require "search/escaping"
require "search/result_set"
require "indexer"
require "indexer/amender"
require "document"

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

    attr_reader :mappings, :index_name

    def initialize(base_uri, index_name, base_index_name, mappings, search_config)
      @base_uri = base_uri
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
        alias_info = @client.indices.get_aliases(index: @index_name)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return nil
      end

      alias_info.keys.first
    end

    def exists?
      ! real_name.nil?
    end

    def close
      @client.indices.close(index: @index_name)
    end

    # Apply a write lock to this index, making it read-only
    def lock
      request_body = { "index" => { "blocks" => { "write" => true } } }
      @client.indices.put_settings(index: @index_name, body: request_body)
    end

    # Remove any write lock applied to this index
    def unlock
      request_body = { "index" => { "blocks" => { "write" => false } } }
      @client.indices.put_settings(index: @index_name, body: request_body)
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

    # Insert or update documents using the elasticsearch _bulk API.
    # Note that this method is used even if we only have one document to index.
    def bulk_index(document_hashes, options = {})
      _bulk(payload_generator.bulk_payload(document_hashes), options)
    end

    # Generic method for calling the _bulk endpoint.
    # Each item is either a command or a document hash.
    # Commands are keyed by operation, eg index, delete, create, update
    # See https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
    # for more information.
    def bulk_commands(command_and_document_hashes, options = {})
      _bulk(payload_generator.bulk_command_payload(command_and_document_hashes), options)
    end

    def amend(document_id, updates)
      Indexer::Amender.new(self).amend(document_id, updates)
    end

    def get_document_by_id(document_id)
      begin
        response = @client.get(index: @index_name, type: "_all", id: document_id)
        document_from_hash(response["_source"])
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
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
      LegacyClient::ScrollEnumerator.new(client: client, index_names: @index_name, search_body: search_body, batch_size: batch_size) do |hit|
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
      LegacyClient::ScrollEnumerator.new(client: @client, index_names: @index_name, search_body: search_body, batch_size: batch_size) do |hit|
        hit.fetch("fields", {})["link"]
      end
    end

    def documents_by_format(format, field_definitions)
      batch_size = 500
      search_body = {
        query: { term: { format: format } },
        fields: field_definitions.keys,
      }

      LegacyClient::ScrollEnumerator.new(client: @client, index_names: @index_name, search_body: search_body, batch_size: batch_size) do |hit|
        LegacyClient::MultivalueConverter.new(hit["fields"], field_definitions).converted_hash
      end
    end

    def advanced_search(params)
      LegacySearch::AdvancedSearch.new(@mappings, @document_types, @client, @index_name).result_set(params)
    end

    def raw_search(payload, type = nil)
      logger.debug "Request payload: #{payload.to_json}"
      @client.search(index: @index_name, type: type, body: payload)
    end

    # Convert a best bet query to a string formed by joining the normalised
    # words in the query with spaces.
    #
    # duplicated in document_preparer.rb
    def analyzed_best_bet_query(query)
      analyzed_query = @client.indices.analyze(index: @index_name, body: query, analyzer: "best_bet_stemmed_match")

      analyzed_query["tokens"].map { |token_info|
        token_info["token"]
      }.join(" ")
    end

    def delete(type, id)
      begin
        @client.delete(index: @index_name, type: type, id: id)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # We are fine with trying to delete deleted documents.
        true
      rescue Elasticsearch::Transport::Transport::Errors::Forbidden => e
        if locked_index_error?(e.message)
          raise IndexLocked
        else
          raise
        end
      end

      true # For consistency with the Solr API and simple_json_response
    end

    def commit
      @client.indices.refresh(index: @index_name)
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
      Services.elasticsearch(hosts: @base_uri, timeout: options[:timeout] || TIMEOUT_SECONDS)
    end

    # `bulk_index` is the only method that inserts/updates documents. The other
    # indexing-methods like `add` and `amend` eventually end up
    # calling this method.
    def _bulk(payload, options = {})
      @client = build_client(options)
      payload_generator = Indexer::BulkPayloadGenerator.new(@index_name, @search_config, @client, @is_content_index)
      response = @client.bulk(index: @index_name, body: payload_generator.bulk_payload(document_hashes_or_payload))

      items = response["items"]
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

    def payload_generator
      Indexer::BulkPayloadGenerator.new(@index_name, @search_config, @client, @is_content_index)
    end
  end
end
