version = File.read(File.expand_path("VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.name          = "ec2spot"
  s.version       = version
  s.summary       = "Wrapper around the AWS SDK for pricing EC2 Spot Instances."
  s.description   = "ec2spot create uses the AWS API to fetch spot prices for a list of instance types. It includes the min, max, avg, and ondemand prices over a seven day period. It also loads an estimate of the interrupts from the spot advisor tool. It expect the AWS client to be configured using one of the standard methods."
  s.authors       = ["Patrick Wiseman"]
  s.email         = "patrick@deft.services"
  s.files         = ["lib/ec2spot.rb", "lib/2024.02.02_SpotAdvisorData.json"]
  s.homepage      = "https://github.com/deftinc/ec2spot"
  s.license       = "MIT"
  s.require_paths = ["lib"]
  s.requirements << "A configured AWS client with access to the EC2 and Pricing APIs."

  s.required_ruby_version = '>= 3.2.0'

  s.metadata = {
    "homepage_uri" => "https://github.com/deftinc/ec2spot",
    "source_code_uri"   => "https://github.com/deftinc/ec2spot/tree/#{version}",
    "rubygems_mfa_required" => "true",
  }

  s.add_dependency "aws-sdk-ec2", ">= 1.437"
  s.add_dependency "aws-sdk-pricing", ">= 1.54"
end
