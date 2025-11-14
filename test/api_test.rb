ENV["MT_NO_PLUGINS"] = "1"

require "minitest/autorun"
require "amplify_syndication"

class StubAPI < AmplifySyndication::API
  attr_reader :calls

  def initialize(responses)
    super(nil)
    @responses = responses.dup
    @calls     = []
  end

  def fetch_with_options(resource, query_options = {})
    @calls << [resource, query_options]
    @responses.shift || { "value" => [] }
  end
end

class AmplifySyndicationAPITest < Minitest::Test
  def test_fetch_all_lookups_uses_paging
    responses = [
      { "value" => [{ "LookupKey" => "1" }, { "LookupKey" => "2" }] },
      { "value" => [] }
    ]

    api      = StubAPI.new(responses)
    lookups  = api.fetch_all_lookups(batch_size: 2, sleep_seconds: 0)

    assert_equal 2, lookups.size
    assert_equal 2, api.calls.size

    first_call = api.calls.first
    assert_equal "Lookup", first_call[0]
    assert_equal({ "$top" => 2, "$skip" => 0 }, first_call[1])
  end

  def test_each_lookup_batch_yields_batches
    responses = [
      { "value" => [{ "LookupKey" => "1" }] },
      { "value" => [{ "LookupKey" => "2" }] },
      { "value" => [] }
    ]

    api = StubAPI.new(responses)
    yielded_keys = []

    api.each_lookup_batch(batch_size: 1, sleep_seconds: 0) do |batch|
      yielded_keys << batch.first["LookupKey"]
    end

    assert_equal ["1", "2"], yielded_keys
  end

  def test_each_initial_download_batch_updates_checkpoint
    first_batch = {
      "value" => [
        { "ListingKey" => "A", "ModificationTimestamp" => "2025-01-01T00:00:00Z" },
        { "ListingKey" => "B", "ModificationTimestamp" => "2025-01-01T00:00:00Z" }
      ]
    }
    second_batch = {
      "value" => [
        { "ListingKey" => "C", "ModificationTimestamp" => "2025-01-02T00:00:00Z" }
      ]
    }

    responses = [first_batch, second_batch, { "value" => [] }]
    api       = StubAPI.new(responses)

    checkpoint = { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
    all_keys   = []

    api.each_initial_download_batch(
      batch_size: 2,
      sleep_seconds: 0,
      checkpoint: checkpoint
    ) do |batch, cp|
      all_keys.concat(batch.map { |row| row["ListingKey"] })
      refute_nil cp[:last_timestamp]
      refute_nil cp[:last_key]
    end

    assert_equal %w[A B C], all_keys
    assert_equal "2025-01-02T00:00:00Z", checkpoint[:last_timestamp]
    assert_equal "C", checkpoint[:last_key]
  end
end