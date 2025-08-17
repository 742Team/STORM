# -*- encoding: utf-8 -*-
# stub: mini_magick 5.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mini_magick".freeze
  s.version = "5.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/minimagick/minimagick/releases" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Corey Johnson".freeze, "Hampton Catlin".freeze, "Peter Kieltyka".freeze, "James Miller".freeze, "Thiago Fernandes Massa".freeze, "Janko Marohni\u0107".freeze]
  s.date = "1980-01-02"
  s.description = "Manipulate images with minimal use of memory via ImageMagick".freeze
  s.email = ["probablycorey@gmail.com".freeze, "hcatlin@gmail.com".freeze, "peter@nulayer.com".freeze, "bensie@gmail.com".freeze, "thiagown@gmail.com".freeze, "janko.marohnic@gmail.com".freeze]
  s.homepage = "https://github.com/minimagick/minimagick".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5".freeze)
  s.requirements = ["You must have ImageMagick installed".freeze]
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "Manipulate images with minimal use of memory via ImageMagick".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<logger>.freeze, [">= 0"])
      s.add_development_dependency(%q<rake>.freeze, [">= 0"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.5"])
    else
      s.add_dependency(%q<logger>.freeze, [">= 0"])
      s.add_dependency(%q<rake>.freeze, [">= 0"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.5"])
    end
  else
    s.add_dependency(%q<logger>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.5"])
  end
end
