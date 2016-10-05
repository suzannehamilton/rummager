# EntityExpander
#
# Takes an elasticsearch result, which can have arrays of slugs and translates
# those into objects with extra data. For example, a result can contain
# organisations like this:
#
#   { "organisations": ["/mod"] }
#
# `#new_result(result)` will replace the slugs by an object from the
# organisations-registry (sourced from the government-index):
#
#  { "organisations": [{ "title": "Ministry of Defence", "slug": "/mod" }] }
#
module Search
  class EntityExpander
    attr_reader :registries

    def initialize(registries)
      @registries = registries
    end

    # Field name to Registry name.
    MAPPING = {
      'document_series' => :document_series,
      'document_collections' => :document_collections,
      'organisations' => :organisations,
      'policy_areas' => :policy_areas,
      'world_locations' => :world_locations,
      'specialist_sectors' => :specialist_sectors,
      'people' => :people
    }.freeze

    def new_result(result)
      MAPPING.each do |field_name, registry_name|
        next unless result[field_name]

        registry = registries[registry_name]
        next unless registry

        result[field_name] = result[field_name].map do |content_id|
          item_from_registry_by_content_id(registry, content_id)
        end
      end

      result
    end

  private

    def item_from_registry_by_content_id(registry, content_id)
      expanded_item = registry.by_content_id(content_id) || {}

      expanded_item.merge("content_id" => content_id)
    end
  end
end
