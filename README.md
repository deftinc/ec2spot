# EC2Spot

Inspired by prior art [lox/ec2spot](https://github.com/lox/ec2spot). EC2Spot takes a list of instance types and dumps out spot pricing over the last 7 days include min, max, and avg spot pricing. It also provides the instance_type, full on-demand price, savings percentage, and an estimate of interrupts from [EC2 Spot Advisor]().

## Configuration

This gem requires [an authenticated AWS client](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/credentials.html). You can use whatever auth you want, but the easiest way to do that is to set environment variables for `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION`.

If you're making new IAM keys you can pretty tightly scope them with the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstanceTypeOfferings",
        "ec2:DescribeSpotPriceHistory",
        "pricing:DescribeServices",
        "pricing:ListPriceLists",
        "pricing:GetAttributeValues",
        "pricing:GetPriceListFileUrl",
        "pricing:GetProducts",
        "ec2:DescribeInstanceTypes"
      ],
      "Resource": "*"
    }
  ]
}
```

```sh
export AWS_ACCESS_KEY_ID="AKIA0123456789012345"
export AWS_SECRET_ACCESS_KEY="someiamsecretaccesskey"
export AWS_REGION="us-east-2"
```

You can unset them to cleanup

```sh
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_REGION
```

## Usage

The class is a singleton so you can grab the instance with `#instance` or if you have updated your config and want to refresh the AWS SDK clients `#instance!`.

```ruby
require "ec2spot"

instances = [
  "m4.large",
  "m5.large"
]

EC2Spot.instance.prices(*instances)
# =>
# [{:instance=>"m4.large", :min=>0.0478, :max=>0.057, :avg=>0.05334242424242424, :full=>0.1, :savings=>0.46657575757575764, :interrupts=>"<5%"},
# {:instance=>"m5.large", :min=>0.031, :max=>0.0338, :avg=>0.03227777777777777, :full=>0.096, :savings=>0.6637731481481481, :interrupts=>"10-15%"}]
```
