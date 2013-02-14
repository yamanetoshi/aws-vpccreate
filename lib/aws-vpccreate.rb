require "aws-vpccreate/version"

require 'aws-sdk'
#require 'singleton'

module AWS
  class Vpccreate
    attr_reader :vpc

    def initialize ec2
      @ec2 = ec2
      @vpc = nil
    end

    def create_vpc cidr_block, options = {}
      @vpc = @ec2.vpcs.create(cidr_block, options)
    end

    def create_subnet cidr_block, options = {}
      raise "no vpc instance" if @vpc == nil

      options[:vpc] = @vpc
      @ec2.subnets.create(cidr_block, options)
    end

    def create_ig
      raise "no vpc instance" if @vpc == nil

      ig = @ec2.internet_gateways.create
      ig.attach @vpc
      ig
    end

    def create_sg name, options = {}
      raise "no vpc instance" if @vpc == nil

      options[:vpc] = @vpc
      @ec2.security_groups.create(name, options)
    end

    def create_rt options = {}
      raise "no vpc instance" if @vpc == nil

      options[:vpc] = @vpc
      @ec2.route_tables.create(options)
    end
  end

  class VPCFactory
#    include Singleton

#    def initialize
    def initialize ec2
      @vpc = nil
      @vpcc = AWS::Vpccreate.new(ec2)
    end

#    def setec2 ec2
#      @vpcc = AWS::Vpccreate.new(ec2)
#    end

    def create config
      raise "no config" if config == {}
      raise "no vpc" if !config.key?('vpc') 
      raise "no vpc_subnet" if !config["vpc"].key?('vpc_subnet')
      raise "no vpc_subnet" if config["vpc"]["vpc_subnet"] == ""

      raise "vpc already exist!" if @vpc != nil

      @vpc = create_vpc_ig(config)
      create_subnet @vpc, config if config["vpc"].key?('subnets')
      create_sg config if config["vpc"].key?('security_group')
    end

    @private
    def create_vpc_ig config
      vpc = @vpcc.create_vpc(config["vpc"]["vpc_subnet"])
      @vpcc.create_ig
      vpc
    end

    def create_subnet vpc, config
      config["vpc"]["subnets"].each { |tmp|
        @vpcc.create_subnet(tmp["subnet_addr"],
                            {:availability_zone => tmp["availability_zone"]})
        @vpcc.create_rt
      }
    end

    def create_sg config
      config["vpc"]["security_group"].each { |tmp|
        @vpcc.create_sg(tmp["name"], {:description => tmp["description"]})
      }
    end
  end
end
