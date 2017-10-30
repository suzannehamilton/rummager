require "gds_api/test_helpers/publishing_api_v2"

module SpecHelpers
  include GdsApi::TestHelpers::PublishingApiV2

  def self.included(base)
    base.after do
      Timecop.return
    end
  end

  def search_query_params(options = {})
    Search::QueryParameters.new({
      start: 0,
      count: 20,
      query: "cheese",
      order: nil,
      filters: {},
      return_fields: nil,
      aggregates: nil,
      debug: {},
      ab_tests: {},
    }.merge(options))
  end

  # This works because we first try to look up the content id for the base path.
  def stub_tagging_lookup
    publishing_api_has_lookups({})
  end

  # need to add additional page_traffic data in order to set maximum allowed ranking value
  def setup_page_traffic_data(document_count:)
    document_count.times.each do |i|
      insert_document("page-traffic_test", { rank_14: i }, id: "/path/#{i}", type: "page-traffic")
    end
    commit_index("page-traffic_test")
  end

  def generate_random_example(schema: "help_page", payload: {}, excluded_fields: [])
    # just in case RandomExample does not generate a type field

    payload[:document_type] ||= schema
    GovukSchemas::RandomExample.for_schema(notification_schema: schema) do |hash|
      hash.merge!(payload.stringify_keys)
      hash.delete_if { |k, _| excluded_fields.include?(k) }
      hash
    end
  end
end
