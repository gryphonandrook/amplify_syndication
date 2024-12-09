require "httpclient"
require "json"
require "uri"

module AmplifySyndication
  class Client
    def initialize
      @http_client = HTTPClient.new
      @base_url = AmplifySyndication.configuration.base_url
      @access_token = AmplifySyndication.configuration.access_token
    end

    def get(endpoint, params = {})
      url = "#{@base_url}/#{endpoint}".gsub(%r{//}, '/').sub(%r{:/}, '://')
      headers = {
        "Authorization" => "Bearer #{@access_token}",
        "Accept" => "application/json"
      }
      response = @http_client.get(url, params, headers)
      parse_response(response)
    end

    def get_with_options(endpoint, options = {})
      query_string = options.map { |key, value| "#{key}=#{value}" }.join("&")
      get("#{endpoint}?#{query_string}")
    end

    private

    # Converts a hash of query options into a URL-encoded query string
    def build_query_string(options)
      URI.encode_www_form(options)
    end

    # Parses JSON response, raises an error for non-200 responses
    def parse_response(response)
      if response.status == 200
        JSON.parse(response.body)
      else
        raise StandardError, "HTTP Error: #{response.status} - #{response.body}"
      end
    end
  end
end
