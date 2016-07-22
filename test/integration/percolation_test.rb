require "integration_test_helper"
require "securerandom"

class PercolationTest < IntegrationTest
  def setup
    stub_elasticsearch_settings
    create_test_indexes
  end

  def teardown
    clean_test_indexes
  end

  def test_global_subscription
    uuid = SecureRandom.uuid
    index.register_percolation_query({}, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "title" => "Some text",
    )

    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]
  end

  def test_multiple_subscriptions
    index.register_percolation_query({})
    index.register_percolation_query({})
    commit_index("government_test")

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "title" => "Some text",
    )

    assert_equal 2, result["total"]
  end

  def test_match_query
    query = {
      "matches" => {
        "title" => "text"
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "title" => "Some text",
    )
    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "title" => "Some other title",
    )
    assert_equal 0, result["total"]
  end

  def test_single_filter
    query = {
      "filters" => {
        "schema_name" => "publication"
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "publication",
    )

    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "news_article",
    )

    assert_equal 0, result["total"]
  end

  def test_multiple_filters
    query = {
      "filters" => {
        "schema_name" => "publication",
        "document_type" => "policy_paper"
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "publication",
      "document_type" => "policy_paper",
    )
    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "publication",
      "document_type" => "guidance",
    )
    assert_equal 0, result["total"]

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "news_article",
      "document_type" => "policy_paper"
    )
    assert_equal 0, result["total"]

    result = index.percolate(
      "created_at" => "2010-10-10T00:00:00",
      "schema_name" => "news_article",
      "document_type" => "speech"
    )
    assert_equal 0, result["total"]
  end

  def test_nested_filters
    query = {
      "filters" => {
        "details.open" => "false"
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "details" => {
        "open" => "false",
      },
    )
    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]

    result = index.percolate(
      "details" => {
        "open" => "true",
      },
    )
    assert_equal 0, result["total"]
  end

  def test_date_range
    query = {
      "ranges" => {
        "public_timestamp" => {
          "after" => "2010-01-01",
          "before" =>"2015-01-01",
        }
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "public_timestamp" => "2012-01-01T00:00:00",
    )
    assert_equal 1, result["total"]
    assert_equal uuid, result["matches"].first["_id"]

    result = index.percolate(
      "created_at" => "2009-01-01T00:00:00",
    )
    assert_equal 0, result["total"]

    result = index.percolate(
      "created_at" => "2016-01-01T00:00:00",
    )
    assert_equal 0, result["total"]
  end

  def test_links_and_matches
    query = {
      "matches" => {
        "title" => "text"
      },
      "filters" => {
        "organisations" => ["hm-revenue-customs"],
      }
    }

    uuid = SecureRandom.uuid
    index.register_percolation_query(query, uuid: uuid)
    commit_index("government_test")

    result = index.percolate(
      "title" => "Some text",
      "links" => {
        "organisations" => ["hm-revenue-customs"],
      }
    )
    assert_equal 1, result["total"]

    result = index.percolate(
      "title" => "A non-matching title",
      "links" => {
        "organisations" => ["hm-revenue-customs"],
      }
    )
    assert_equal 0, result["total"]

    result = index.percolate(
      "title" => "Some text",
      "links" => {
        "organisations" => ["a-non-matching-org"],
      }
    )
    assert_equal 0, result["total"]
  end

  # Links
  def test_links_are_additive_within_a_single_type
    # We should only match subscriptions whose links are a full subset of the document's links
    hmrc_only, hmrc_and_cab_office, hmrc_and_env_agency = setup_org_subscriptions

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs"],
    })
    assert_equal 1, result["total"]
    assert_equal [hmrc_only], result["matches"].map { |match| match["_id"] }

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs", "cabinet-office"]
    })
    assert_equal 2, result["total"]
    assert_equal [hmrc_only, hmrc_and_cab_office].to_set,
                 result["matches"].map { |match| match["_id"] }.to_set

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs", "cabinet-office", "environment-agency"]
    })
    assert_equal 3, result["total"]
    assert_equal [hmrc_only, hmrc_and_cab_office, hmrc_and_env_agency].to_set,
                 result["matches"].map { |match| match["_id"] }.to_set

    result = index.percolate("links" => {
      "organisations" => ["cabinet-office"]
    })
    assert_equal 0, result["total"]

    result = index.percolate("links" => {
      "organisations" => ["cabinet-office", "environment-agency"]
    })
    assert_equal 0, result["total"]
  end

  def test_links_are_additive_across_types
    # We should only match subscriptions whose links are a full subset of the document's links
    org_only, org_and_topic, org_and_policy = setup_type_subscriptions

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs"],
    })
    assert_equal 1, result["total"]
    assert_equal [org_only], result["matches"].map { |match| match["_id"] }

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs"],
      "topics" => ["oil-and-gas/licensing"],
    })
    assert_equal 2, result["total"]
    assert_equal [org_only, org_and_topic].to_set,
                 result["matches"].map { |match| match["_id"] }.to_set

    result = index.percolate("links" => {
      "organisations" => ["hm-revenue-customs"],
      "topics" => ["oil-and-gas/licensing"],
      "policies" => ["climate-change"],
    })
    assert_equal 3, result["total"]
    assert_equal [org_only, org_and_topic, org_and_policy].to_set,
                 result["matches"].map { |match| match["_id"] }.to_set

    result = index.percolate("links" => {
      "topics" => ["oil-and-gas/licensing"],
    })
    assert_equal 0, result["total"]

    result = index.percolate("links" => {
      "topics" => ["oil-and-gas/licensing"],
      "policies" => ["climate-change"],
    })
    assert_equal 0, result["total"]
  end

private

  def setup_org_subscriptions
    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs"],
      }
    }
    hmrc_only = SecureRandom.uuid
    index.register_percolation_query(query, uuid: hmrc_only)

    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs", "cabinet-office"],
      }
    }
    hmrc_and_cab_office = SecureRandom.uuid
    index.register_percolation_query(query, uuid: hmrc_and_cab_office)

    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs", "environment-agency"],
      }
    }
    hmrc_and_env_agency = SecureRandom.uuid
    index.register_percolation_query(query, uuid: hmrc_and_env_agency)

    commit_index("government_test")

    [hmrc_only, hmrc_and_cab_office, hmrc_and_env_agency]
  end

  def setup_type_subscriptions
    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs"],
      }
    }
    org_only = SecureRandom.uuid
    index.register_percolation_query(query, uuid: org_only)

    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs"],
        "topics" => ["oil-and-gas/licensing"],
      }
    }
    org_and_topic = SecureRandom.uuid
    index.register_percolation_query(query, uuid: org_and_topic)

    query = {
      "filters" => {
        "organisations" => ["hm-revenue-customs"],
        "policies" => ["climate-change"],
      }
    }
    org_and_policy = SecureRandom.uuid
    index.register_percolation_query(query, uuid: org_and_policy)

    commit_index("government_test")

    [org_only, org_and_topic, org_and_policy]
  end

  def index
    search_server.index("government_test")
  end
end
