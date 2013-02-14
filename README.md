# Aws::Vpccreate

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'aws-vpccreate'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aws-vpccreate

## Usage

    require 'yaml'
    require 'aws-sdk'
    require 'aws-vpccreate'
	
	AWS.config(YAML.load(File.read(File.join(File.dirname(__FILE__). 'aws.yml'))))
	ec2 = AWS::EC2.new
	vpcf = AWS::VPCFactory.new(ec2)
	
	vpc_config = YAML.load(File.read(File.join(File.dirname(__FILE__). 'vpc.yml'))))
	vpcf.create(vpc_config)
	
	puts vpcf.vpcc.logger.config_log

vpc.yml example is the following

	vpc: 
	  vpc_subnet: '10.0.0.0/16'
      subnets:
        - subnet_addr: '10.0.0.0/24'
          availability_zone: 'ap-northeast-1a'
        - subnet_addr: '10.0.1.0/24'
          availability_zone: 'ap-northeast-1b'
        - subnet_addr: '10.0.2.0/24'
          availability_zone: 'ap-northeast-1b'
        - subnet_addr: '10.0.3.0/24'
          availability_zone: 'ap-northeast-1c'
      security_group:
        - name: 'abc'
          description: 'NAT'
        - name: 'def'
          description: 'WEB'
        - name: 'ghi'
          description: 'DB'

aws.yml example is the following

    access_key_id: my_acess_key
    secret_access_key: my_secret_access_key
    ec2_endpoint: ec2.ap-northeast-1.amazonaws.com


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
