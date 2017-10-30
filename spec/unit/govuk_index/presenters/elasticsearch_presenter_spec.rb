require 'spec_helper'

RSpec.describe GovukIndex::ElasticsearchPresenter do
  it "identifier" do
    payload = generate_random_example(payload: { payload_version: 1 })

    expected_identifier = {
      _type: payload["document_type"],
      _id: payload["base_path"],
      version: 1,
      version_type: "external"
    }

    presenter = elasticsearch_presenter(payload, "help_page")

    expect(expected_identifier).to eq(presenter.identifier)
  end

  it "raise_validation_error" do
    payload = {}

    presenter = elasticsearch_presenter(payload)

    expect {
      presenter.valid!
    }.to raise_error(GovukIndex::ValidationError)
  end

  def elasticsearch_presenter(payload, type = "aaib_report")
    allow_any_instance_of(GovukIndex::DocumentTypeInferer).to receive(:type).and_return(type)
    described_class.new(
      payload: payload,
      type_inferer: GovukIndex::DocumentTypeInferer
    )
  end
end
