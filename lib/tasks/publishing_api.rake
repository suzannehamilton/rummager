namespace :publishing_api do
  desc "Publish special routes such as sitemaps"
  task :publish_special_routes do
    require 'gds_api/publishing_api/special_route_publisher'

    publishing_api = GdsApi::PublishingApiV2.new(
      Plek.new.find('publishing-api'),
      bearer_token: ENV['PUBLISHING_API_BEARER_TOKEN'] || 'example'
    )

    publisher = GdsApi::PublishingApi::SpecialRoutePublisher.new(
      logger: Logger.new(STDOUT),
      publishing_api: publishing_api
    )

    routes = [
      {
        base_path: "/sitemap.xml",
        content_id: "fee32a90-397a-4761-9f98-b06e47d2b798",
        title: "GOV.UK sitemap index",
        description: "Provides the locations of the GOV.UK sitemaps.",
        type: "exact",
      },
      {
        base_path: "/sitemaps",
        content_id: "c202c6a5-656c-40d1-ae55-36fab995709c",
        title: "GOV.UK sitemaps prefix",
        description: "The prefix URL under which our XML sitemaps are located.",
        type: "prefix",
      },
    ]

    routes.each do |route|
      begin
        payload = route.merge(
          format: "special_route",
          publishing_app: "rummager",
          rendering_app: "rummager",
          public_updated_at: Time.now.iso8601,
          update_type: "major",
        )

        publisher.publish(payload)
      rescue GdsApi::TimedOutException
        puts "WARNING: publishing-api timed out when trying to publish route #{payload.inspect}"
      rescue GdsApi::HTTPServerError => e
        puts "WARNING: publishing-api errored out when trying to publish route #{payload.inspect}\n\nError: #{e.inspect}"
      end
    end
  end
end
