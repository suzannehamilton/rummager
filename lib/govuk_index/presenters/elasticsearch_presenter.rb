module GovukIndex
  class ElasticsearchPresenter
    delegate :unpublishing_type?, to: :@infered_type

    def initialize(payload:, type_inferer: GovukIndex::DocumentTypeInferer)
      @payload = payload
      @infered_type ||= type_inferer.new(payload)
    end

    def type
      @type ||= @infered_type.type
    end

    def identifier
      {
        _type: type,
        _id: base_path,
        version: payload["payload_version"],
        version_type: "external",
      }
    end

    def document
      {
        aircraft_category:                  specialist.aircraft_category,
        aircraft_type:                      specialist.aircraft_type,
        alert_issue_date:                   specialist.alert_issue_date,
        alert_type:                         specialist.alert_type,
        assessment_date:                    specialist.assessment_date,
        build_end_date:                     specialist.build_end_date,
        build_start_date:                   specialist.build_start_date,
        business_sizes:                     specialist.business_sizes,
        business_stages:                    specialist.business_stages,
        case_state:                         specialist.case_state,
        case_type:                          specialist.case_type,
        closed_date:                        specialist.closed_date,
        closing_date:                       specialist.closing_date,
        contact_groups:                     details.contact_groups,
        content_id:                         common_fields.content_id,
        content_store_document_type:        common_fields.content_store_document_type,
        continuation_link:                  specialist.continuation_link,
        country:                            specialist.country,
        date_of_occurrence:                 specialist.date_of_occurrence,
        description:                        common_fields.description,
        development_sector:                 specialist.development_sector,
        dfid_authors:                       specialist.dfid_authors,
        dfid_document_type:                 specialist.dfid_document_type,
        dfid_review_status:                 specialist.dfid_review_status,
        dfid_theme:                         specialist.dfid_theme,
        eligible_entities:                  specialist.eligible_entities,
        email_document_supertype:           common_fields.email_document_supertype,
        fault_type:                         specialist.fault_type,
        faulty_item_model:                  specialist.faulty_item_model,
        faulty_item_type:                   specialist.faulty_item_type,
        first_published_at:                 specialist.first_published_at,
        format:                             common_fields.format,
        fund_state:                         specialist.fund_state,
        fund_type:                          specialist.fund_type,
        funding_amount:                     specialist.funding_amount,
        funding_source:                     specialist.funding_source,
        government_document_supertype:      common_fields.government_document_supertype,
        grant_type:                         specialist.grant_type,
        hidden_indexable_content:           specialist.hidden_indexable_content,
        indexable_content:                  indexable.indexable_content,
        industries:                         specialist.industries,
        is_withdrawn:                       common_fields.is_withdrawn,
        issued_date:                        specialist.issued_date,
        land_use:                           specialist.land_use,
        licence_identifier:                 details.licence_identifier,
        licence_short_description:          details.licence_short_description,
        link:                               common_fields.link,
        location:                           specialist.location,
        mainstream_browse_page_content_ids: expanded_links.mainstream_browse_page_content_ids,
        mainstream_browse_pages:            expanded_links.mainstream_browse_pages,
        manufacturer:                       specialist.manufacturer,
        market_sector:                      specialist.market_sector,
        medical_specialism:                 specialist.medical_specialism,
        navigation_document_supertype:      common_fields.navigation_document_supertype,
        opened_date:                        specialist.opened_date,
        organisation_content_ids:           expanded_links.organisation_content_ids,
        organisations:                      expanded_links.organisations,
        outcome_type:                       specialist.outcome_type,
        part_of_taxonomy_tree:              expanded_links.part_of_taxonomy_tree,
        popularity:                         common_fields.popularity,
        primary_publishing_organisation:    expanded_links.primary_publishing_organisation,
        public_timestamp:                   common_fields.public_timestamp,
        publishing_app:                     common_fields.publishing_app,
        railway_type:                       specialist.railway_type,
        registration:                       specialist.registration,
        rendering_app:                      common_fields.rendering_app,
        report_type:                        specialist.report_type,
        search_user_need_document_supertype:common_fields.search_user_need_document_supertype,
        serial_number:                      specialist.serial_number,
        specialist_sectors:                 expanded_links.specialist_sectors,
        taxons:                             expanded_links.taxons,
        therapeutic_area:                   specialist.therapeutic_area,
        tiers_or_standalone_items:          specialist.tiers_or_standalone_items,
        title:                              common_fields.title,
        topic_content_ids:                  expanded_links.topic_content_ids,
        tribunal_decision_categories:       specialist.tribunal_decision_categories,
        tribunal_decision_category:         specialist.tribunal_decision_category,
        tribunal_decision_country:          specialist.tribunal_decision_country,
        tribunal_decision_decision_date:    specialist.tribunal_decision_decision_date,
        tribunal_decision_judges:           specialist.tribunal_decision_judges,
        tribunal_decision_landmark:         specialist.tribunal_decision_landmark,
        tribunal_decision_reference_number: specialist.tribunal_decision_reference_number,
        tribunal_decision_sub_categories:   specialist.tribunal_decision_sub_categories,
        tribunal_decision_sub_category:     specialist.tribunal_decision_sub_category,
        types_of_support:                   specialist.types_of_support,
        user_journey_document_supertype:    common_fields.user_journey_document_supertype,
        value_of_funding:                   specialist.value_of_funding,
        vessel_type:                        specialist.vessel_type,
        will_continue_on:                   specialist.will_continue_on,
      }.reject { |_, v| v.nil? }
    end

    def format
      common_fields.format
    end

    def base_path
      @_base_path ||= payload["base_path"]
    end

    def valid!
      return if base_path
      raise(ValidationError, "base_path missing from payload")
    end

  private

    attr_reader :payload

    def common_fields
      @_common_fields ||= CommonFieldsPresenter.new(payload)
    end

    def indexable
      IndexableContentPresenter.new(
        format: common_fields.format,
        details: payload["details"],
        sanitiser: IndexableContentSanitiser.new,
      )
    end

    def details
      @_details ||= DetailsPresenter.new(details: payload["details"], format: common_fields.format)
    end

    def expanded_links
      @_expanded_links ||= ExpandedLinksPresenter.new(payload["expanded_links"])
    end

    def specialist
      @_specialist ||= SpecialistPresenter.new(metadata: payload.dig("details", "metadata"))
    end
  end
end
