require 'services'

# LinksLookup finds the tags (links) from the publishing-api and merges them into
# the document. If there aren't any links, the payload will be returned unchanged.
module Indexer
  class LinksLookup
    def initialize
      @logger = Logging.logger[self]
    end

    def self.prepare_tags(doc_hash)
      new.prepare_tags(doc_hash)
    end

    def prepare_tags(doc_hash)
      # Rummager contains externals links (that have a full URL in the `link`
      # field). These won't have tags associated with them so we can bail out.
      return doc_hash if doc_hash["link"] =~ /\Ahttps?:\/\//

      # Bail out if the base_path doesn't exist in publishing-api
      content_id = find_content_id(doc_hash)
      return doc_hash unless content_id

      # Bail out if the base_path doesn't exist in publishing-api
      links = find_links(content_id)
      return doc_hash unless links

      doc_hash.merge(taggings_with_content_ids(links))
    end

  private

    # Some applications send the `content_id` for their items. This means we can
    # skip the lookup from the publishing-api.
    def find_content_id(doc_hash)
      if doc_hash["content_id"].present?
        doc_hash["content_id"]
      else
        GdsApi.with_retries(maximum_number_of_attempts: 5) do
          Services.publishing_api.lookup_content_id(base_path: doc_hash["link"])
        end
      end
    end

    def find_links(content_id)
      begin
        GdsApi.with_retries(maximum_number_of_attempts: 5) do
          Services.publishing_api.get_expanded_links(content_id)['expanded_links']
        end
      rescue GdsApi::TimedOutException => e
        @logger.error("Timeout fetching expanded links for #{content_id}")
        raise e
      end
    end

    def taggings_with_content_ids(links)
      {
        'specialist_sectors' => content_ids_for(links, 'topics'),
        'mainstream_browse_pages'=> content_ids_for(links, 'mainstream_browse_pages'),
        'organisations' => content_ids_for(links, 'organisations'),
        'taxons' => content_ids_for(links, 'taxons'),
      }
    end

    def content_ids_for(links, link_type)
      links[link_type].to_a.map do |content_item|
        content_item['content_id']
      end
    end
  end
end
