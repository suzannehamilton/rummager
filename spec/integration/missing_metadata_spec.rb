require 'spec_helper'

RSpec.describe 'MissingMetadataTest' do
  it "finds_missing_content_id" do
    commit_document(
      'mainstream_test',
      'link' => '/path/to_page',
    )

    runner = MissingMetadata::Runner.new('content_id', search_config: SearchConfig.instance, logger: io)
    results = runner.retrieve_records_with_missing_value

    expect([{ _id: '/path/to_page', index: 'mainstream_test' }]).to eq results
  end

  it "ignores_already_set_content_id" do
    commit_document(
      'mainstream_test',
      'link' => '/path/to_page',
      'content_id' => '8aea1742-9cc6-4dfb-a63b-12c3e66a601f',
    )

    runner = MissingMetadata::Runner.new('content_id', search_config: SearchConfig.instance, logger: io)
    results = runner.retrieve_records_with_missing_value

    expect(results).to be_empty
  end

  it "finds_missing_document_type" do
    commit_document(
      'mainstream_test',
      'link' => '/path/to_page',
      'content_id' => '8aea1742-9cc6-4dfb-a63b-12c3e66a601f',
    )

    runner = MissingMetadata::Runner.new('content_store_document_type', search_config: SearchConfig.instance, logger: io)
    results = runner.retrieve_records_with_missing_value

    expect([{ _id: '/path/to_page', index: 'mainstream_test', content_id: '8aea1742-9cc6-4dfb-a63b-12c3e66a601f' }]).to eq results
  end

  it "ignores_already_set_document_type" do
    commit_document(
      'mainstream_test',
      'link' => '/path/to_page',
      'content_id' => '8aea1742-9cc6-4dfb-a63b-12c3e66a601f',
      'content_store_document_type' => 'guide',
    )

    runner = MissingMetadata::Runner.new('content_store_document_type', search_config: SearchConfig.instance, logger: io)
    results = runner.retrieve_records_with_missing_value

    expect(results).to be_empty
  end

  def io
    @io ||= StringIO.new
  end
end
