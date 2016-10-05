class IntegrationTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods
  include Fixtures::DefaultMappings

  SAMPLE_DOCUMENT_ATTRIBUTES = {
    "title" => "TITLE1",
    "description" => "DESCRIPTION",
    "format" => "local_transaction",
    "link" => "/URL"
  }.freeze

  AUXILIARY_INDEX_NAMES = ["page-traffic_test", "metasearch_test"].freeze
  INDEX_NAMES = %w(mainstream_test government_test).freeze
  DEFAULT_INDEX_NAME = INDEX_NAMES.first

  def sample_document
    Document.from_hash(SAMPLE_DOCUMENT_ATTRIBUTES, sample_document_types)
  end

  def insert_document(index_name, attributes)
    attributes.stringify_keys!
    type = attributes["_type"] || "edition"
    client.create(
      index: index_name,
      type: type,
      id: attributes['link'],
      body: attributes
    )
  end

  def commit_document(index_name, attributes)
    insert_document(index_name, attributes)
    commit_index(index_name)
  end

  def commit_index(index_name = "mainstream_test")
    client.indices.refresh(index: index_name)
  end

  def app
    Rummager
  end

  def client
    @client ||= Services::elasticsearch(hosts: 'http://localhost:9200')
  end

  def parsed_response
    JSON.parse(last_response.body)
  end

  def assert_document_is_in_rummager(document)
    retrieved = fetch_document_from_rummager(link: document['link'])

    document.each do |key, value|
      assert_equal value, retrieved[key],
        "Field #{key} should be '#{value}' but was '#{retrieved[key]}'"
    end
  end

  def create_meta_indexes
    AUXILIARY_INDEX_NAMES.each do |index|
      create_test_index(index)
    end
  end

  def clean_meta_indexes
    AUXILIARY_INDEX_NAMES.each do |index|
      clean_index_group(index)
    end
  end

  def reset_content_indexes_with_content(params = { section_count: 2 })
    reset_content_indexes
    populate_content_indexes(params)
  end

  def sample_document_attributes(index_name, section_count)
    short_index_name = index_name.sub("_test", "")
    (1..section_count).map do |i|
      title = "Sample #{short_index_name} document #{i}"
      if i % 2 == 1
        title = title.downcase
      end
      fields = {
        "title" => title,
        "link" => "/#{short_index_name}-#{i}",
        "indexable_content" => "Something something important content id #{i}",
      }
      fields["mainstream_browse_pages"] = [i.to_s]
      if i % 2 == 0
        fields["specialist_sectors"] = ["farming-content-id"]
      end
      if short_index_name == "government"
        fields["public_timestamp"] = "#{i + 2000}-01-01T00:00:00"
      end
      fields
    end
  end

  def add_sample_documents(index_name, count)
    attributes = sample_document_attributes(index_name, count)
    attributes.each do |sample_document|
      insert_document(index_name, sample_document)
    end

    commit_index(index_name)
  end

  def check_index_name!(index_name)
    unless /^[a-z_-]+(_|-)test($|-)/ =~ index_name
      raise "#{index_name} is not a valid test index name"
    end
  end

  def stub_elasticsearch_settings
    (INDEX_NAMES + AUXILIARY_INDEX_NAMES).each do |index_name|
      check_index_name!(index_name)
    end

    app.settings.search_config.stubs(:elasticsearch).returns({
      "base_uri" => "http://localhost:9200",
      "content_index_names" => INDEX_NAMES,
      "auxiliary_index_names" => AUXILIARY_INDEX_NAMES,
      "metasearch_index_name" => "metasearch_test",
      "registry_index" => "government_test",
      "spelling_index_names" => INDEX_NAMES,
      "popularity_rank_offset" => 10,
    })
    app.settings.stubs(:default_index_name).returns(DEFAULT_INDEX_NAME)
  end

  def search_config
    app.settings.search_config
  end

  def search_server
    search_config.search_server
  end

  def reset_content_indexes
    INDEX_NAMES.each do |index_name|
      try_remove_test_index(index_name)
      create_test_index(index_name)
    end
  end

  def create_test_index(group_name = DEFAULT_INDEX_NAME)
    index_group = search_server.index_group(group_name)
    index = index_group.create_index
    index_group.switch_to(index)
  end

  def create_test_indexes
    (AUXILIARY_INDEX_NAMES + INDEX_NAMES).each do |index|
      create_test_index(index)
    end
  end

  def clean_test_indexes
    (AUXILIARY_INDEX_NAMES + INDEX_NAMES).each do |index|
      clean_index_group(index)
    end
  end

  def try_remove_test_index(index_name = DEFAULT_INDEX_NAME)
    check_index_name!(index_name)
    if client.indices.exists?(index: index_name)
      client.indices.delete(index: index_name)
    end
  end

  def clean_index_group(group_name = DEFAULT_INDEX_NAME)
    check_index_name!(group_name)
    index_group = search_server.index_group(group_name)
    # Delete any indices left over from switching
    index_group.clean
    # Clean up the test index too, to avoid the possibility of inter-dependent
    # tests. It also keeps the index view cleaner.
    if index_group.current.exists?
      index_group.send(:delete, index_group.current.real_name)
    end
  end

  def stub_index
    @stubbed_index ||= begin
      stubbed_index = stub("stub index")
      Rummager.any_instance.stubs(:current_index).returns(stubbed_index)
      Rummager.any_instance.stubs(:unified_index).returns(stubbed_index)
      stubbed_index
    end
  end

private

  def populate_content_indexes(params)
    INDEX_NAMES.each do |index_name|
      add_sample_documents(index_name, params[:section_count])
    end
  end

  def fetch_document_from_rummager(link:)
    response = client.get(
      index: 'mainstream_test',
      type: '_all',
      id: link
    )
    response['_source']
  end
end
