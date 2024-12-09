module AmplifySyndication
  class API
    def initialize(client = Client.new)
      @client = client
    end

    # Fetch metadata
    def fetch_metadata
      @client.get("$metadata?$format=json")
    end

    # Fetch basic property data
    def fetch_property_data(limit = 1)
      @client.get("Property", "$top" => limit)
    end

    # Fetch data with query options
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

    ### Replication Methods ###

    # Perform initial download for replication
    def perform_initial_download(
      resource: "Property",
      batch_size: 100,
      fields: ["ModificationTimestamp", "ListingKey"],
      filter: nil,
      checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
    )
      puts "Starting initial download..."
      all_records = [] # Array to collect all records

      loop do
        puts "Fetching batch with timestamp > #{checkpoint[:last_timestamp]} and key > #{checkpoint[:last_key]}..."

        # Build batch filter
        batch_filter = []
        batch_filter << "#{filter}" if filter
        batch_filter << "(ModificationTimestamp gt #{URI.encode_www_form_component(checkpoint[:last_timestamp])})"
        batch_filter << "or (ModificationTimestamp eq #{URI.encode_www_form_component(checkpoint[:last_timestamp])} and ListingKey gt '#{checkpoint[:last_key]}')"
        batch_filter = batch_filter.join(" ")

        # Query options
        query_options = {
          "$select" => fields.join(","),
          "$filter" => batch_filter,
          "$orderby" => "ModificationTimestamp,ListingKey",
          "$top" => batch_size
        }

        # Debugging: Print the full query options
        puts "Query options: #{query_options.inspect}"

        # Send request
        response = fetch_with_options(resource, query_options)
        records = response["value"]
        break if records.empty?

        # Collect batch records
        all_records.concat(records)

        # Update checkpoint with the last record in the batch
        last_record = records.last
        checkpoint[:last_timestamp] = last_record["ModificationTimestamp"]
        checkpoint[:last_key] = last_record["ListingKey"]

        # Stop if the number of records is less than the batch size
        break if records.size < batch_size
      end

      puts "Initial download complete."
      all_records # Return the collected records
    end

    # Fetch updates since the last checkpoint
    def fetch_updates(
        resource: "Property",
        batch_size: 100,
        fields: ["ModificationTimestamp", "ListingKey"],
        filter: nil,
        checkpoint: { last_timestamp: "1970-01-01T00:00:00Z", last_key: 0 }
      )
      perform_initial_download(
        resource: resource,
        batch_size: batch_size,
        fields: fields,
        filter: filter,
        checkpoint: checkpoint
      ) do |batch|
        # Process updates
        yield(batch) if block_given?
      end
    end

    # Fetch full details of a property by ListingKey
    def fetch_property_by_key(listing_key)
      endpoint = "Property('#{listing_key}')"
      puts "Fetching property details for ListingKey: #{listing_key}"
      @client.get(endpoint)
    end

    ### Media Methods ###

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
        "$filter" => "#{filter} and ModificationTimestamp ge #{modification_date}",
        "$orderby" => orderby,
        "$top" => batch_size
      }
      fetch_with_options("Media", query_options)
    end

    # Fetch media by ResourceName and ResourceRecordKey
    def fetch_media_by_resource(resource_name, resource_key, batch_size = 100)
      filter = "ResourceRecordKey eq '#{resource_key}' and ResourceName eq '#{resource_name}'"
      query_options = {
        "$filter" => filter,
        "$orderby" => "ModificationTimestamp,MediaKey",
        "$top" => batch_size
      }
      fetch_with_options("Media", query_options)
    end
  end
end
