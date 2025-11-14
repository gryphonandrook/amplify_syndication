# Amplify Syndication Gem

## Overview

`amplify_syndication` is a Ruby gem that provides a simple interface to interact with the Amplify Syndication API. It includes methods to manage properties, media, and other related resources in real estate applications.

---

## Features

- Fetch and manage **Property** resources:
  - Retrieve specific properties by `ListingKey`
  - Query for properties with advanced filtering and sorting
- Fetch and manage **Media** resources:
  - Retrieve specific media by `MediaKey`
  - Query for media associated with properties, offices, and members
- Easy-to-use replication features for synchronizing data

---

## Installation

Add the gem to your Gemfile:

```bash
gem 'amplify_syndication'
```

Then run:

```bash
bundle install
```

Or install it manually:

```bash
gem install amplify_syndication
```

---

## Configuration

You need to configure the base URL and access token for the Amplify Syndication API. Add the following to your application’s initializer or a setup script:

```bash
AmplifySyndication.configure do |config|
  config.base_url = "https://query.ampre.ca/odata"
  config.access_token = "your_api_access_token_here"
end
```

---

## Usage

### Initialize the API

Create an instance of the API:

```bash
api = AmplifySyndication::API.new
```

---

## Properties

### Fetch Metadata

Retrieve metadata for the API:

```bash
metadata = api.fetch_metadata
puts metadata
```

### Replication: Initial Download

Perform an initial download of properties for replication:

```bash
properties = api.perform_initial_download(batch_size: 100)
puts "Downloaded #{properties.size} properties."
```

### Fetch Property by ListingKey

Retrieve full details of a property by its ListingKey:

```bash
property = api.fetch_property_by_key("12345")
puts property
```

### Fetch Filtered Properties

Query for properties with advanced filtering:

```bash
filtered_properties = api.fetch_filtered_properties(
  filter: "City eq 'Toronto' and ListPrice gt 500000",
  select: "ListingKey,City,ListPrice",
  orderby: "ListPrice desc",
  top: 10
)
puts filtered_properties
```

### Fetch Property Count

Get the total count of properties:

```bash
count = api.fetch_property_count
puts "Total properties: #{count['@odata.count']}"
```

---

## Media

### Fetch Media by MediaKey

Retrieve full details of a media record by its MediaKey:

```bash
media = api.fetch_media_by_key("61400d19-417e-4f43-b36e-efffb352a128")
puts media
```

### Fetch Media by Resource

Retrieve all media records associated with a specific resource:

```bash
property_media = api.fetch_media_by_resource("Property", "12345")
puts property_media
```

### Fetch Recent Media

Query for recently created or modified media:

```bash
recent_media = api.fetch_recent_media(
  filter: "ResourceName eq 'Property'",
  modification_date: "2023-12-01T00:00:00Z"
)
puts recent_media
```

---

## Lookups

### Fetch all lookups (simple)

Fetch the entire `Lookup` table into memory:

```ruby
api = AmplifySyndication::API.new

lookups = api.fetch_all_lookups(
  batch_size: 100,
  sleep_seconds: 2 # optional throttle between API calls
)

puts "Loaded #{lookups.size} lookup rows"

---

## Error Handling

If an API call fails, the gem raises a StandardError with details of the HTTP response:

```bash
begin
  property = api.fetch_property_by_key("invalid_key")
rescue StandardError => e
  puts "Error: #{e.message}"
end
```

---

## Contributing

  1.  Fork the repository
  2.  Create a feature branch (git checkout -b feature/new-feature)
  3.  Commit your changes (git commit -m 'Add a new feature')
  4.  Push to the branch (git push origin feature/new-feature)
  5.  Create a Pull Request

---

Bug reports and pull requests are welcome on GitHub at https://github.com/gryphonandrook/amplify_syndication.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
