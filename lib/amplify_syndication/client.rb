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
      query_string = build_query_string(options)
      get("#{endpoint}?#{query_string}")
    end

    private

    def build_query_string(options)
      options.map do |key, value|
        escaped_value = URI::DEFAULT_PARSER.escape(value.to_s)
        "#{key}=#{escaped_value}"
      end.join("&")
    end

    def parse_response(response)
      if response.status == 200
        JSON.parse(response.body)
      else
        raise StandardError, "HTTP Error: #{response.status} - #{response.body}"
      end
    end
  end
end
