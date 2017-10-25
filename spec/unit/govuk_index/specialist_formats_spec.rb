require 'spec_helper'

RSpec.describe GovukIndex::ElasticsearchPresenter, 'Specialist formats' do
  before do
    allow_any_instance_of(Indexer::PopularityLookup).to receive(:lookup_popularities).and_return({})
  end

  it "aaib_report" do
    custom_metadata = {
      "date_of_occurrence" => "2015-10-10",
      "aircraft_category" => ["commercial-fixed-wing"],
      "report_type" => "annual-safety-report",
      "location" => "Near Popham Airfield, Hampshire",
      "aircraft_type" => "Alpi (Cavaciuti) Pioneer 400",
      "registration" => "G-CGVO",
    }
    special_formated_output = {
      "report_type" => ["annual-safety-report"],
      "location" => ["Near Popham Airfield, Hampshire"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "asylum_support_decision" do
    custom_metadata = {
      "hidden_indexable_content" => "some hidden content",
      "tribunal_decision_categories" => ["section-95-support-for-asylum-seekers"],
      "tribunal_decision_decision_date" => "2015-10-10",
      "tribunal_decision_judges" => ["bayati-c"],
      "tribunal_decision_landmark" => "not-landmark",
      "tribunal_decision_reference_number" => "1234567890",
      "tribunal_decision_sub_categories" => ["section-95-destitution"],
    }
    # The following fields are valid for the object, however they can not be edited in the
    # front end.
    # * tribunal_decision_category
    # * tribunal_decision_sub_category

    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
    expect(document[:indexable_content]).to eq("Test body\n\n\nsome hidden content")
  end

  it "business_finance_support_scheme" do
    custom_metadata = {
      "business_sizes" => ["under-10", "between-10-and-249"],
      "business_stages" => ["start-up"],
      "continuation_link" => "https://www.gov.uk",
      "industries" => ["information-technology-digital-and-creative"],
      "types_of_support" => ["finance"],
      "will_continue_on" => "on GOV.UK",
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
  end

  it "cma_case" do
    custom_metadata = {
      "opened_date" => "2014-01-01",
      "closed_date" => "2015-01-01",
      "case_type" => "ca98-and-civil-cartels",
      "case_state" => "closed",
      "market_sector" => ["energy"],
      "outcome_type" => "ca98-no-grounds-for-action-non-infringement",
    }
    special_formated_output = {
      "case_type" => ["ca98-and-civil-cartels"],
      "case_state" => ["closed"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "countryside_stewardship_grant" do
    custom_metadata = {
      "grant_type" => "option",
      "land_use" => ["priority-habitats", "trees-non-woodland", "uplands"],
      "tiers_or_standalone_items" => ["higher-tier"],
      "funding_amount" => ["201-to-300"],
    }
    special_formated_output = {
      "grant_type" => ["option"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "dfid_research_output" do
    custom_metadata = {
      "dfid_document_type" => "book_chapter",
      "country" => ["GB"],
      "dfid_authors" => ["Mr. Potato Head", "Mrs. Potato Head"],
      "dfid_theme" => ["infrastructure"],
      "first_published_at" => "2016-04-28",
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
  end

  it "drug_safety_update" do
    custom_metadata = {
      "therapeutic_area" => ["cancer", "haematology", "immunosuppression-transplantation"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
  end

  it "employment_appeal_tribunal_decision" do
    custom_metadata = {
      "hidden_indexable_content" => "hidden content",
      "tribunal_decision_categories" => ["age-discrimination"],
      "tribunal_decision_decision_date" => "2015-07-30",
      "tribunal_decision_landmark" => "landmark",
      "tribunal_decision_sub_categories" => ["contract-of-employment-apprenticeship"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
    expect(document[:indexable_content]).to eq("Test body\n\n\nhidden content")
  end

  it "employment_tribunal_decision" do
    custom_metadata = {
      "hidden_indexable_content" => "hidden etd content",
      "tribunal_decision_categories" => ["age-discrimination"],
      "tribunal_decision_country" => "england-and-wales",
      "tribunal_decision_decision_date" => "2015-07-30",
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
    expect(document[:indexable_content]).to eq("Test body\n\n\nhidden etd content")
  end

  it "european_structural_investment_fund" do
    custom_metadata = {
      "closing_date" => "2016-01-01",
      "fund_state" => "open",
      "fund_type" => ["business-support"],
      "location" => ["south-west"],
      "funding_source" => ["european-regional-development-fund"],
    }
    special_formated_output = {
      "fund_state" => ["open"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "international_development_fund" do
    custom_metadata = {
      "closing_date" => "2016-01-01",
      "fund_state" => "open",
      "fund_type" => ["business-support"],
      "location" => ["south-west"],
      "funding_source" => ["european-regional-development-fund"],
    }
    special_formated_output = {
      "fund_state" => ["open"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "maib_report" do
    custom_metadata = {
      "date_of_occurrence" => "2015-10-10",
      "report_type" => "investigation-report",
      "vessel_type" => ["merchant-vessel-100-gross-tons-or-over"],
    }
    special_formated_output = {
      "report_type" => ["investigation-report"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "medical_safety_alert" do
    custom_metadata = {
      "alert_type" => "company-led-drugs",
      "issued_date" => "2016-02-01",
      "medical_specialism" => %w(anaesthetics cardiology),
    }
    special_formated_output = {
      "alert_type" => ["company-led-drugs"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "raib_report" do
    custom_metadata = {
      "date_of_occurrence" => "2015-10-10",
      "report_type" => "investigation-report",
      "railway_type" => ["heavy-rail"],
    }
    special_formated_output = {
      "report_type" => ["investigation-report"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata.merge(special_formated_output))
  end

  it "service_standard_report" do
    custom_metadata = {
      "assessment_date" => "2016-10-10"
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
  end


  it "tax_tribunal_decision" do
    custom_metadata = {
      "hidden_indexable_content" => "hidden ttd content",
      "tribunal_decision_category" => "banking",
      "tribunal_decision_decision_date" => "2015-07-30",
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
    expect(document[:indexable_content]).to eq("Test body\n\n\nhidden ttd content")
  end

  it "utaac_decision" do
    custom_metadata = {
      "hidden_indexable_content" => "hidden utaac content",
      "tribunal_decision_categories" => ["Benefits for children"],
      "tribunal_decision_decision_date" => "2016-01-01",
      "tribunal_decision_judges" => ["angus-r"],
      "tribunal_decision_sub_categories" => ["benefits-for-children-benefit-increases-for-children"],
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
    expect(document[:indexable_content]).to eq("Test body\n\n\nhidden utaac content")
  end

  it "vehicle_recalls_and_faults_alert" do
    custom_metadata = {
      "alert_issue_date" => "2015-04-28",
      "build_start_date" => "2015-04-28",
      "build_end_date" => "2015-06-28",
      "fault_type" => "recall",
      "faulty_item_type" => "other-accessories",
      "manufacturer" => "nim-engineering-ltd",
      "faulty_item_model" => "Cable Recovery Winch",
      "serial_number" => "SN123",
    }
    document = build_example_with_metadata(custom_metadata)
    expect_document_include_hash(document, custom_metadata)
  end

private

  def build_example_with_metadata(metadata)
    example = GovukSchemas::RandomExample
                .for_schema(notification_schema: 'specialist_document')
                .customise_and_validate(
                  'details' => {
                    'body' => 'Test body',
                    'change_history' => [],
                    'metadata' => metadata,
                  }
                )
    described_class.new(payload: example).document
  end


  def expect_document_include_hash(document, hash)
    hash.each do |key, value|
      expect(document[key.to_sym]).to eq(value),
        "Value for #{key}: `#{document[key.to_sym]}` did not match expected value `#{value}`"
    end
  end
end
