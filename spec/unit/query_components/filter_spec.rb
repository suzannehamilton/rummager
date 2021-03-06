require 'spec_helper'

RSpec.describe QueryComponents::Filter do
  def make_search_params(filters, include_withdrawn: true)
    Search::QueryParameters.new(filters: filters, debug: { include_withdrawn: include_withdrawn })
  end

  def make_date_filter_param(field_name, values)
    SearchParameterParser::DateFieldFilter.new(field_name, values, false)
  end

  def text_filter(field_name, values)
    SearchParameterParser::TextFieldFilter.new(field_name, values, false)
  end

  def reject_filter(field_name, values)
    SearchParameterParser::TextFieldFilter.new(field_name, values, true)
  end

  context "search with one filter" do
    it "append the correct text filters" do
      builder = described_class.new(
        make_search_params([text_filter("organisations", ["hm-magic"])])
      )

      result = builder.payload

      expect(result).to eq("terms" => { "organisations" => ["hm-magic"] })
    end

    it "append the correct date filters" do
      builder = described_class.new(
        make_search_params([make_date_filter_param("field_with_date", ["from:2014-04-01 00:00,to:2014-04-02 00:00"])])
      )

      result = builder.payload

      expect(result).to eq("range" => { "field_with_date" => { "from" => "2014-04-01T00:00:00+00:00", "to" => "2014-04-02T00:00:00+00:00" } })
    end
  end

  context "search with a filter with multiple options" do
    it "have correct filter" do
      builder = described_class.new(
        make_search_params([text_filter("organisations", ["hm-magic", "hmrc"])])
      )

      result = builder.payload

      expect(result).to eq("terms" => { "organisations" => ["hm-magic", "hmrc"] })
    end
  end

  context "search with a filter and rejects" do
    it "have correct filter" do
      builder = described_class.new(
        make_search_params(
          [
            text_filter("organisations", ["hm-magic", "hmrc"]),
            reject_filter("mainstream_browse_pages", ["benefits"]),
          ]
        )
      )

      result = builder.payload

      expect(result).to eq(
        bool: {
          must: { "terms" => { "organisations" => ["hm-magic", "hmrc"] } },
          must_not: { "terms" => { "mainstream_browse_pages" => ["benefits"] } },
        }
      )
    end
  end

  context "search with multiple filters" do
    it "have correct filter" do
      builder = described_class.new(
        make_search_params(
          [
            text_filter("organisations", ["hm-magic", "hmrc"]),
            text_filter("mainstream_browse_pages", ["levitation"]),
          ],
        )
      )

      result = builder.payload

      expect(result).to eq(
        and: [
          { "terms" => { "organisations" => ["hm-magic", "hmrc"] } },
          { "terms" => { "mainstream_browse_pages" => ["levitation"] } },
        ].compact
      )
    end
  end
end
