require 'spec_helper'

RSpec.describe Indexer::DocumentPreparer do
  describe "#prepared" do
    it "populates popularities" do
      stub_tagging_lookup

      doc_hash = {
        "link" => "/some-link",
      }

      updated_doc_hash = described_class.new("fake_client", "fake_index").prepared(
        doc_hash,
        { "/some-link" => 0.5 }, true
      )

      expect(0.5).to eq(updated_doc_hash["popularity"])
    end

    it "adds document type groupings" do
      stub_tagging_lookup

      doc_hash = {
        "link" => "/some-link",
        "content_store_document_type" => "detailed_guide",
      }

      updated_doc_hash = described_class.new("fake_client", "fake_index").prepared(
        doc_hash,
        {},
        true
      )

      expect(updated_doc_hash["navigation_document_supertype"]).to eq("guidance")
    end
  end
end
