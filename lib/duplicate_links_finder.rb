class DuplicateLinksFinder
  def initialize(elasticsearch_url, indices)
    @client = Elasticsearch::Client.new(host: elasticsearch_url)
    @indices = indices
  end

  def find_exact_duplicates
    body = {
      "query": {
        "match_all": {}
      },
      "aggs": {
        "duplicates": {
          "terms": {
            "field": "link",
            "order": {
              "_count": "desc"
            },
            "size": 100000,
            "min_doc_count": 2
          }
        }
      }
    }

    results = client.search(index: indices, body: body)
    results["aggregations"]["duplicates"]["buckets"].map { |duplicate| duplicate["key"] }
  end

  # Find items whose link is a full URL which duplicate items whose links are just the path
  # e.g. `https://www.gov.uk/ministers` and `/ministers`
  def find_full_url_duplicates(query)
    results = client.search(index: indices, body: query)

    results['hits']['hits'].select do |item|
      link = item['_source']['link']
      if link.start_with?('https://www.gov.uk')
        result = find_path_duplicate(link)

        if result['hits']['hits'].empty?
          puts "Skipping #{link} as it has no duplicates"
          false
        else
          puts "Including #{link} for deletion"
          true
        end
      else
        puts "Skipping #{item['link']} as it does not start with https://www.gov.uk"
        false
      end
    end
  end

private

  attr_reader :client, :indices

  def find_path_duplicate(link)
    client.search(
      index: indices,
      body: {
        filter: {
          term: {
            link: link.gsub('https://www.gov.uk', '')
          }
        }
      }
    )
  end
end
