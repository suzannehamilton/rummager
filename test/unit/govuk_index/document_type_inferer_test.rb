require "test_helper"

class GovukIndex::DocumentTypeInfererTest < Minitest::Test
  def test_infer_payload_document_type
    payload = {
      "base_path" => "/cheese",
      "document_type" => "cheddar"
    }

    document_type_inferer = GovukIndex::DocumentTypeInferer.new(payload)

    assert_equal payload["document_type"], document_type_inferer.type
  end

  def test_should_raise_not_found_error
    payload = { "document_type" => "gone" }

    GovukIndex::DocumentTypeInferer.any_instance.stubs(:existing_document).returns(nil)

    assert_raises(GovukIndex::NotFoundError) do
      GovukIndex::DocumentTypeInferer.new(payload).type
    end
  end

  def test_infer_existing_document_type
    payload = {
      "base_path" => "/cheese",
      "document_type" => "redirect"
    }

    existing_document = {
      "_type" => "cheddar",
      "_id" => "/cheese"
    }

    GovukIndex::DocumentTypeInferer.any_instance.stubs(:existing_document).returns(existing_document)

    document_type_inferer = GovukIndex::DocumentTypeInferer.new(payload)

    assert_equal existing_document["_type"], document_type_inferer.type
  end
end