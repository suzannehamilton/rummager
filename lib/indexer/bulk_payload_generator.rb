module Indexer
  class BulkPayloadGenerator
    def initialize(index_name, search_config, client, is_content_index)
      @index_name = index_name
      @search_config = search_config
      @client = client
      @is_content_index = is_content_index
    end

    # Payload to index documents using the `_bulk` endpoint
    # Takes an array of document hashes and returns a string to send to
    # elasticsearch, for example:
    #
    #   {"index": {"_type": "edition", "_id": "/bank-holidays"}}
    #   { <document source> }
    #   {"index": {"_type": "edition", "_id": "/something-else"}}
    #   { <document source> }
    #
    # See <http://www.elasticsearch.org/guide/reference/api/bulk/>
    def bulk_payload(document_hashes)
      index_items_from_document_hashes(document_hashes)
    end

    # Construct arbitrary payloads for the `_bulk` endpoint
    # Takes an array of hashes representing elasticsearch commands and
    # document hashes, for example:
    #
    #   {"index": {"_type": "edition", "_id": "/bank-holidays"}}
    #   { <document source> }
    #   {"index": {"_type": "edition", "_id": "/something-else"}}
    #   { <document source> }
    #
    # Adds in popularity information and returns a string to return to
    # elasticsearch.
    # See <http://www.elasticsearch.org/guide/reference/api/bulk/> for more
    # on the format.
    def bulk_command_payload(command_and_document_hashes)
      actions = []
      links = []
      command_and_document_hashes.each_slice(2).map do |command_hash, doc_hash|
        actions << [command_hash, doc_hash]
        links << doc_hash["link"]
      end
      popularities = lookup_popularities(links.compact)
      actions.flat_map { |command_hash, doc_hash|
        if command_hash.keys == ["index"]
          doc_hash["_type"] = command_hash["index"]["_type"]
          [
            command_hash,
            index_doc(doc_hash, popularities),
          ]
        else
          [
            command_hash,
            doc_hash,
          ]
        end
      }
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
