require "uri"

module AmplifySyndication
  class API
    def initialize(client = Client.new)
      @client = client
    end

    # === Metadata ===

    # Fetch metadata
    def fetch_metadata
      @client.get("$metadata?$format=json")
    end

    # === Field helpers ===

    # Fetch all Field records for the Property resource in a single call
    # (still paginated under the hood).
    def fetch_property_fields(batch_size: 50, sleep_seconds: 10)
      offset = 0
      fields = []

      loop do
        query_options = {
          "$filter" => "ResourceName eq 'Property'",
          "$top"    => batch_size,
          "$skip"   => offset
        }.compact

        response = fetch_with_options("Field", query_options)
        batch    = response["value"] || []
        break if batch.empty?

        fields.concat(batch)
        offset += batch_size

        sleep(sleep_seconds) if sleep_seconds.positive?
      end

      fields
    end

    # === Lookup helpers ===

    # Fetch a single Lookup page (batch) with optional filter.
    #
    # filter can be:
    #   - a String: "LookupStatus eq 'Active'"
    #   - an Array of strings: ["LookupStatus eq 'Active'", "LookupName eq 'PropertyType'"]
    def fetch_lookup_batch(skip:, top: 50, filter: nil)
      query_options = {
        "$top"  => top,
        "$skip" => skip
      }

      if filter
        combined_filter =
          filter.is_a?(Array) ? filter.join(" and ") : filter
        query_options["$filter"] = combined_filter
      end

      response = fetch_with_options("Lookup", query_options)
      response["value"] || []
    end

    # Iterate over Lookup records in batches, yielding each batch.
    #
    # Example:
    #   api.each_lookup_batch(batch_size: 100, filter: "LookupStatus eq 'Active'") do |batch|
    #     batch.each { |row| VowLookup.upsert_from_row(row) }
    #   end
    def each_lookup_batch(batch_size: 50, sleep_seconds: 10, filter: nil)
      skip = 0

      loop do
        batch = fetch_lookup_batch(skip: skip, top: batch_size, filter: filter)
        break if batch.empty?

        yield(batch) if block_given?

        skip += batch_size
        sleep(sleep_seconds) if sleep_seconds.positive?
      end
    end

    # Fetch all Lookup rows into memory (simple usage).
    #
    # For long-running syncs, prefer each_lookup_batch so your app can
    # handle persistence/checkpointing per batch.
    def fetch_all_lookups(batch_size: 50, sleep_seconds: 10, filter: nil)
      results = []

      each_lookup_batch(batch_size: batch_size,
                        sleep_seconds: sleep_seconds,
                        filter: filter) do |batch|
        results.concat(batch)
      end

      results
    end

    # Get all rows for a single LookupName (convenience helper).
    def lookup(lookup_name, batch_size: 50, sleep_seconds: 10)
      offset = 0
      values = []

      loop do
        query_options = {
          "$filter" => "LookupName eq '#{lookup_name}'",
          "$top"    => batch_size,
          "$skip"   => offset
        }.compact

        response = fetch_with_options("Lookup", query_options)
        batch    = response["value"] || []
        break if batch.empty?

        values.concat(batch)
        offset += batch_size

        sleep(sleep_seconds) if sleep_seconds.positive?
      end

      values
    end

    # === Property helpers ===

    # Fetch basic property data (simple test helper)
    def fetch_property_data(limit = 1)
      @client.get("Property", "$top" => limit)
    end

    # Fetch data with query options against an arbitrary resource
    def fetch_with_options(resource, query_options = {})
      @client.get_with_options(resource, query_options)
    end

    # Fetch properties with specific filtering, sorting, and pagination
    def fetch_filtered_properties(filter: nil, select: nil, orderby: nil, top: nil, skip: nil, count: nil)
      query_options = {
        "$filter" => filter,
        "$select" => select,
        "$orderby" => orderby,
        "$top" => top,
        "$skip" => skip,
        "$count" => count
      }.compact

      fetch_with_options("Property", query_options)
    end

    # Fetch the total count of properties
    def fetch_property_count
      fetch_filtered_properties(count: "true", top: 0)
    end

    # === Replication helpers ===
    #
    # These three methods give you flexible control:
    #
    #   - fetch_initial_download_batch  -> single page
    #   - each_initial_download_batch  -> yields per page
    #   - perform_initial_download     -> fetch everything into memory

    # Build and fetch a single replication batch for a resource.
    def fetch_initial_download_batch(
      resource: "Property",
      batch_size: 100,
      fields: ["ModificationTimestamp", "ListingKey"],
      filter: nil,
      checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
    )
      encoded_ts = URI.encode_www_form_component(checkpoint[:last_timestamp])

      # checkpoint filter: everything strictly after the last (timestamp, key) pair
      checkpoint_filter = "(ModificationTimestamp gt #{encoded_ts}) " \
                          "or (ModificationTimestamp eq #{encoded_ts} and ListingKey gt '#{checkpoint[:last_key]}')"

      conditions = []
      conditions << "(#{filter})" if filter
      conditions << "(#{checkpoint_filter})"

      query_options = {
        "$select" => fields.join(","),
        "$filter" => conditions.join(" and "),
        "$orderby" => "ModificationTimestamp,ListingKey",
        "$top" => batch_size
      }

      response = fetch_with_options(resource, query_options)
      response["value"] || []
    end

    # Iterate over replication batches, yielding [batch, checkpoint].
    #
    # You can persist checkpoint per batch to resume later if something fails.
    def each_initial_download_batch(
      resource: "Property",
      batch_size: 100,
      fields: ["ModificationTimestamp", "ListingKey"],
      filter: nil,
      sleep_seconds: 10,
      checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
    )
      loop do
        batch = fetch_initial_download_batch(
          resource: resource,
          batch_size: batch_size,
          fields: fields,
          filter: filter,
          checkpoint: checkpoint
        )

        break if batch.empty?

        yield(batch, checkpoint) if block_given?

        # Update checkpoint automatically based on the last record in the batch
        last_record = batch.last
        checkpoint[:last_timestamp] = last_record["ModificationTimestamp"]
        checkpoint[:last_key]       = last_record["ListingKey"]

        break if batch.size < batch_size

        sleep(sleep_seconds) if sleep_seconds.positive?
      end
    end

    # Perform initial download for replication, buffering all results
    # into memory (simple usage).
    #
    # For large datasets, prefer each_initial_download_batch.
    def perform_initial_download(
      resource: "Property",
      batch_size: 100,
      fields: ["ModificationTimestamp", "ListingKey"],
      filter: nil,
      sleep_seconds: 10,
      checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
    )
      results = []

      puts "Starting initial download..."

      each_initial_download_batch(
        resource: resource,
        batch_size: batch_size,
        fields: fields,
        filter: filter,
        sleep_seconds: sleep_seconds,
        checkpoint: checkpoint
      ) do |batch, _checkpoint|
        results.concat(batch)
      end

      puts "Initial download complete."
      results
    end

    # Fetch updates since the last checkpoint.
    #
    # If a block is given, yields each batch; otherwise returns all
    # updates in a single array (same as perform_initial_download).
    def fetch_updates(
      resource: "Property",
      batch_size: 100,
      fields: ["ModificationTimestamp", "ListingKey"],
      filter: nil,
      checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 },
      sleep_seconds: 10
    )
      if block_given?
        each_initial_download_batch(
          resource: resource,
          batch_size: batch_size,
          fields: fields,
          filter: filter,
          sleep_seconds: sleep_seconds,
          checkpoint: checkpoint
        ) do |batch, cp|
          yield(batch, cp)
        end
        nil
      else
        perform_initial_download(
          resource: resource,
          batch_size: batch_size,
          fields: fields,
          filter: filter,
          sleep_seconds: sleep_seconds,
          checkpoint: checkpoint
        )
      end
    end

    # Fetch full details of a property by ListingKey
    def fetch_property_by_key(listing_key)
      endpoint = "Property('#{listing_key}')"
      puts "Fetching property details for ListingKey: #{listing_key}"
      @client.get(endpoint)
    end

    # === Media helpers ===

    # Fetch a media record by MediaKey
    def fetch_media_by_key(media_key)
      endpoint = "Media('#{media_key}')"
      @client.get(endpoint)
    end

    # Fetch recently created/modified media records
    def fetch_recent_media(
      filter: "ImageSizeDescription eq 'Large' and ResourceName eq 'Property'",
      modification_date: "2023-07-27T04:00:00Z",
      orderby: "ModificationTimestamp,MediaKey",
      batch_size: 100
    )
      query_options = {
        "$filter"  => "#{filter} and ModificationTimestamp ge #{modification_date}",
        "$orderby" => orderby,
        "$top"     => batch_size
      }

      fetch_with_options("Media", query_options)
    end

    def fetch_all_media_for_resource(resource_name, resource_key, batch_size: 100, sleep_seconds: 1)
      filter = "(ResourceRecordKey eq '#{resource_key}' and ResourceName eq '#{resource_name}')"

      results = []
      skip = 0

      loop do
        query_options = {
          "$filter" => filter,
          "$orderby" => "ModificationTimestamp,MediaKey",
          "$top"     => batch_size,
          "$skip"    => skip
        }

        response = fetch_with_options("Media", query_options)
        batch = response["value"] || []
        break if batch.empty?

        results.concat(batch)

        break if batch.size < batch_size
        skip += batch_size
        sleep(sleep_seconds)
      end

      results
    end
  end
end