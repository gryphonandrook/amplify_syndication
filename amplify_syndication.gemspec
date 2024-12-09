# frozen_string_literal: true

require_relative "lib/amplify_syndication/version"

Gem::Specification.new do |spec|
  spec.name = "amplify_syndication"
  spec.version = AmplifySyndication::VERSION
  spec.authors = ["Stephen Higgins"]
  spec.email = ["stephen@gryphonandrook.com"]

  spec.summary       = "An API client for Amplify Syndication services"
  spec.description   = "Provides a Ruby interface for interacting with the Amplify Syndication API."
  spec.homepage      = "https://github.com/gryphonandrook/amplify_syndication"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.add_runtime_dependency 'httpclient', '~> 2.8'

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gryphonandrook/amplify_syndication"
  spec.metadata["changelog_uri"] = "https://github.com/gryphonandrook/amplify_syndication/CHANGELOG.md"

  # Exclude .gemspec and other unwanted files explicitly
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || # Exclude the .gemspec itself
        f.end_with?(".gem") || # Exclude any .gem files
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end