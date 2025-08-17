# -*- encoding: utf-8 -*-
# stub: lz4-ruby 0.3.3 ruby lib
# stub: ext/lz4ruby/extconf.rb

Gem::Specification.new do |s|
  s.name = "lz4-ruby".freeze
  s.version = "0.3.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["KOMIYA Atsushi".freeze]
  s.date = "2014-07-10"
  s.description = "Ruby bindings for LZ4. LZ4 is a very fast lossless compression algorithm.".freeze
  s.email = "komiya.atsushi@gmail.com".freeze
  s.extensions = ["ext/lz4ruby/extconf.rb".freeze]
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "README.rdoc".freeze]
  s.files = ["LICENSE.txt".freeze, "README.rdoc".freeze, "ext/lz4ruby/extconf.rb".freeze]
  s.homepage = "http://github.com/komiya-atsushi/lz4-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9".freeze)
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "Ruby bindings for LZ4 (Extremely Fast Compression algorithm).".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_development_dependency(%q<jeweler>.freeze, ["~> 1.8.3"])
      s.add_development_dependency(%q<rake-compiler>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rspec>.freeze, [">= 0"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_dependency(%q<jeweler>.freeze, ["~> 1.8.3"])
      s.add_dependency(%q<rake-compiler>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<jeweler>.freeze, ["~> 1.8.3"])
    s.add_dependency(%q<rake-compiler>.freeze, [">= 0"])
  end
end
