module AmplifySyndication
  class Configuration
    attr_accessor :access_token, :base_url

    def initialize
      @access_token = nil
      @base_url = "https://query.ampre.ca/odata"
    end
  end
end
