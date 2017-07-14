module Indexer
  class BulkPayloadGenerator
    def initialize(index_name, search_config, client, is_content_index)
      @index_name = index_name
      @search_config = search_config
      @client = client
      @is_content_index = is_content_index
    end

    # Payload to index documents using the `_bulk` endpoint
    #
    # The format is as follows:
    #
    #   {"index": {"_type": "edition", "_id": "/bank-holidays"}}
    #   { <document source> }
    #   {"index": {"_type": "edition", "_id": "/something-else"}}
    #   { <document source> }
    #
    # See <http://www.elasticsearch.org/guide/reference/api/bulk/>
    def bulk_payload(document_hashes_or_payload)
      index_items_from_document_hashes(document_hashes_or_payload)
    end

  private

    def index_items_from_document_hashes(document_hashes)
      links = document_hashes.map { |doc_hash|
        doc_hash["link"]
      }.compact
      popularities = lookup_popularities(links)
      document_hashes.flat_map { |doc_hash|
        [index_action(doc_hash), index_doc(doc_hash, popularities)]
      }
    end

    def lookup_popularities(links)
      Indexer::PopularityLookup.new(@index_name, @search_config).lookup_popularities(links)
    end

    def index_action(doc_hash)
      {
        "index" => {
          "_type" => doc_hash["_type"],
          "_id" => (doc_hash["_id"] || doc_hash["link"])
        }
      }
    end

    def index_doc(doc_hash, popularities)
      DocumentPreparer.new(@client, @index_name).prepared(
        doc_hash,
        popularities,
        @is_content_index
      )
    end
  end
end
