# frozen_string_literal: true

require_relative "amplify_syndication/version"
require_relative "amplify_syndication/configuration"
require_relative "amplify_syndication/api"
require_relative "amplify_syndication/client"

module AmplifySyndication
  class Error < StandardError; end
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end
end
