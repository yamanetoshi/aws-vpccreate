require "aws-vpccreate/version"

require 'aws-sdk'
#require 'singleton'

module AWS
  class Logger
    attr_reader :config_log

    def initialize
      @config_log = { :vpc => { :vpc_subnet => "", 
          :vpc_id => "",
          :subnets => [],
          :security_group => []}}
    end

    def put hash
      if hash[:key] == :vpc_subnet
        @config_log[:vpc][hash[:key]] = hash[:value]
      elsif hash[:key] == :vpc_id
        @config_log[:vpc][hash[:key]] = hash[:value]
      else
        @config_log[:vpc][hash[:key]].push hash[:value]
      end
    end
  end

  class Vpccreate
    attr_reader :vpc, :logger

    def initialize ec2
      @logger = Logger.new
      @ec2 = ec2
      @vpc = nil
    end

    def create_vpc cidr_block, options = {}
      @vpc = @ec2.vpcs.create(cidr_block, options)

      @logger.put({:key => :vpc_subnet, :value => cidr_block})
      @logger.put({:key => :vpc_id, :value => @vpc.id})

      @vpc
    end

    def create_subnet cidr_block, options = {}
      raise "no vpc instance" if @vpc == nil

      @logger.put({:key => :subnets, 
                    :value => {:subnet_addr => cidr_block,
                      :availability_zone => options[:availability_zone]}})

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

      @logger.put({ :key => :security_group,
                    :value => { :name => name, 
                      :description => options[:description]}})

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
    attr_reader :vpcc
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
