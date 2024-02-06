require "aws-sdk-ec2"
require "aws-sdk-pricing"
require "time"

class EC2Spot
  private_class_method :new

  def self.instance
    @instance ||= new
  end

  def self.instance!
    @instance = new
  end

  def prices(*instance_types)
    json = spot_price_history(*instance_types).group_by(&:instance_type).map do |instance_type, spot_price_history|
      prices = spot_price_history.map(&:spot_price).map(&:to_f)
        {
          instance: instance_type,
          min: prices.min,
          max: prices.max,
          avg: prices.sum / prices.length,
          full: instance_price(instance_type),
          savings: (1 - (prices.sum / prices.length) / instance_price(instance_type)),
          interrupts: spot_advisor_range(instance_type)
        }
    end
  end

  private

  def services(service_code, next_token: nil)
    resp = @pricing_client.describe_services({
      service_code: service_code,
      format_version: "aws_v1",
      next_token: next_token,
      max_results: 100,
    })
    json = resp.services
    if !resp.next_token.nil? && !resp.next_token.empty?
      json += services(service_code, next_token: resp.next_token)
    end
    json
  end

  def attribute_values(service_code, attribute_name, next_token: nil)
    resp = @pricing_client.get_attribute_values({
      service_code: service_code,
      attribute_name: attribute_name,
      next_token: next_token,
      max_results: 100,
    })
    json = resp.attribute_values
    if !resp.next_token.nil? && !resp.next_token.empty?
      json += attribute_values(service_code, attribute_name, next_token: resp.next_token)
    end
    json
  end

  def instance_price(instance_type)
    data = products("AmazonEC2", instance_type)
    data["terms"]["OnDemand"].first[1]["priceDimensions"].first[1]["pricePerUnit"]["USD"].to_f
  end

  def products(service_code, instance_type, next_token: nil)
    resp = @pricing_client.get_products({
      service_code: service_code,
      filters: [
        {
          type: "TERM_MATCH",
          field: "instanceType",
          value: instance_type,
        },
        {
          type: "TERM_MATCH",
          field: "regionCode",
          value: @region,
        },
        {
          type: "TERM_MATCH",
          field: "operatingSystem",
          value: "Linux",
        },
        {
          type: "TERM_MATCH",
          field: "usagetype",
          value: "USE2-BoxUsage:#{instance_type}",
        },
        {
          type: "TERM_MATCH",
          field: "operation",
          value: "RunInstances",
        }
      ],
      format_version: "aws_v1",
      next_token: next_token,
      max_results: 100,
    })
    json = resp.price_list
    if resp.price_list.length > 1 || (!resp.next_token.nil? && !resp.next_token.empty?)
      throw "Only expected one result, but got #{json.length}"
    end
    JSON.parse(json.first)
  end

  def instance_types()
    resp = @ec2_client.describe_instance_type_offerings({
      max_results: 1000
    })
    resp.instance_type_offerings
  end

  def spot_price_history(*instance_types, next_token: nil)
    now = Time.now.utc
    its_been_one_week = now - (60 * 60 * 24 * 7)
    json = []
    resp = @ec2_client.describe_spot_price_history({
      end_time: now,
      instance_types: instance_types,
      product_descriptions: [
        "Linux/UNIX (Amazon VPC)",
      ],
      start_time: its_been_one_week,
      max_results: 1000,
      next_token: next_token
    })
    json = resp.spot_price_history
    if !resp.next_token.nil? && !resp.next_token.empty?
      json += spot_price_history(*instance_types, next_token: resp.next_token)
    end
    json
  end

  def instance_type_info(*instance_types, next_token: nil)
    json = []
    resp = @ec2_client.describe_instance_types({
      instance_types: instance_types,
      next_token: next_token
    })
    json = resp.instance_types
    if !resp.next_token.nil? && !resp.next_token.empty?
      json += instance_type_info(*instance_types, next_token: resp.next_token)
    end
    json
  end

  def spot_advisor_range(instance_type)
    @spot_advisor_ranges[@spot_advisor[instance_type]["r"]]
  end

  def initialize
    @ec2_client = Aws::EC2::Client.new()
    @pricing_client = Aws::Pricing::Client.new(region: "us-east-1")
    @region = ENV.fetch("AWS_REGION", "us-east-2")
    data = nil
    begin
      url = URI.parse("https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      request = Net::HTTP::Get.new(url.path)
      response = http.request(request)
      data = JSON.parse(response.body)
    rescue => e
      puts "Failed to fetch spot-advisor-data.json from S3: #{e.message} using local file instead."
      current_directory = File.dirname(__FILE__)
      filepath = File.join(current_directory, "2024.02.02_SpotAdvisorData.json")
      data = JSON.parse(File.read(filepath))
    end
    @spot_advisor = data["spot_advisor"][@region]["Linux"]
    @spot_advisor_ranges = [
      "<5%",
      "5-10%",
      "10-15%",
      "15-20%",
      ">20%",
    ]
    self
  end
end
