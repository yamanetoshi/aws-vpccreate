require 'spec_helper'

describe AWS::VPCFactory do
  let!(:config) { AWS.config.with(:stub_requests => true,
                                 :access_key_id => "AKID",
                                 :secret_access_key => 'b') }
  let!(:ec2) { AWS::EC2.new(:config => config) }

  let(:create_vpc_response) { ec2.client.stub_for(:create_vpc) }

  let(:vpc_details) {{
      :vpc_id => 'vpc-12345',
      :state => 'pending',
      :cidr_block => '192.0.0.0/16',
      :dhcp_option_id => 'dopt-12345',
      :instance_tenancy => 'default',
    }}

  before(:each) do
    create_vpc_response.data[:vpc] = vpc_details
    ec2.client.stub(:create_vpc).and_return(create_vpc_response)
  end

  describe 'create' do
    it 'no configuration (config is {})' do
      config = {}
      proc { AWS::VPCFactory.create(ec2, config) }.should raise_error
    end

    it 'no configuration' do
      proc { AWS::VPCFactory.create(ec2) }.should raise_error
    end

    it 'no vpc_subnet' do
      config = {"vpc" => {}}

      proc { AWS::VPCFactory.create(ec2, config) }.should raise_error
    end

    it 'vpc_subnet is null-string' do
      config = {"vpc" => {"vpc_subnet" => ""}}

      proc { AWS::VPCFactory.create(ec2, config) }.should raise_error
    end

    describe 'makes vpc and internet_gateway only' do
      let(:create_response) { ec2.client.stub_for(:create_internet_gateway) }
      let(:attach_response) { ec2.client.stub_for(:attach_internet_gateway) }

      before(:each) do
        create_response.data[:internet_gateway] = { 
          :internet_gateway_id => 'igw-123',
        }
        ec2.client.stub(:create_internet_gateway).and_return(create_response)
      end

      it 'create vpc and create internet gateway and attach it to vpc' do
        vpc_config = {"vpc" => {"vpc_subnet" => "10.0.0.0/16"}}

        ec2.client.should_receive(:create_vpc).
          with(:cidr_block => '10.0.0.0/16', :instance_tenancy => 'default').
          and_return(create_vpc_response)

        ec2.client.should_receive(:create_internet_gateway).
          with(no_args).and_return(create_response)

        ec2.client.should_receive(:attach_internet_gateway).
          with(:internet_gateway_id => 'igw-123',
               :vpc_id => 'vpc-12345').and_return(attach_response)

        ec2.client.should_not_receive(:create_subnet)
        ec2.client.should_not_receive(:create_route_table)

        ec2.client.should_not_receive(:create_security_group)

        vpcf = AWS::VPCFactory.new ec2
        vpcf.create(vpc_config)
      end
    end

    describe 'makes vpc and ig and security_gateway' do
      let(:create_response) { ec2.client.stub_for(:create_internet_gateway) }
      let(:attach_response) { ec2.client.stub_for(:attach_internet_gateway) }
      let(:create_sg_response) { ec2.client.stub_for(:create_security_group) }

      before(:each) do
        create_response.data[:internet_gateway] = { 
          :internet_gateway_id => 'igw-123',
        }
        ec2.client.stub(:create_internet_gateway).and_return(create_response)

        create_sg_response.data[:group_id] = 'group-id'
        ec2.client.stub(:create_security_group).and_return(create_sg_response)
      end

      it 'create security gateway' do
        vpc_config = {"vpc" => {"vpc_subnet" => "10.0.0.0/16",
            "security_group" => [{"name" =>"abc",
                                   "description" => "NAT"},
                                 {"name" =>"def",
                                   "description" => "WEB"},
                                 {"name" =>"ghi",
                                   "description" => "DB"},
                                ]}}

        ec2.client.should_receive(:create_vpc).
          with(:cidr_block => '10.0.0.0/16', :instance_tenancy => 'default').
          and_return(create_vpc_response)

        ec2.client.should_receive(:create_internet_gateway).
          with(no_args).and_return(create_response)

        ec2.client.should_receive(:attach_internet_gateway).
          with(:internet_gateway_id => 'igw-123',
               :vpc_id => 'vpc-12345').and_return(attach_response)

        ec2.client.should_not_receive(:create_subnet)
        ec2.client.should_not_receive(:create_route_table)

        ec2.client.should_receive(:create_security_group)

        vpcf = AWS::VPCFactory.new ec2
        vpcf.create(vpc_config)
      end
    end

    describe 'makes vpc and ig and subnet and route' do
      let(:create_response) { ec2.client.stub_for(:create_internet_gateway) }
      let(:attach_response) { ec2.client.stub_for(:attach_internet_gateway) }
      let(:create_subnet_response) { ec2.client.stub_for(:create_subnet) }
      let(:create_route_response) { ec2.client.stub_for(:create_route_table) }
      let(:create_sg_response) { ec2.client.stub_for(:create_security_group) }

      let(:subnet_details) {{
          :subnet_id => 'subnet-12345',
          :vpc_id => 'vpc-12345',
          :state => 'pending',
          :cidr_block => '192.0.0.0/16',
          :available_ip_address_count => 50,
          :availability_zone => 'us-east-1c',
        }}

      let(:route_details) {{
          :route_table_id => 'rt-123',
          :vpc_id => 'vpc-12345',
        }}

      before(:each) do
        create_response.data[:internet_gateway] = { 
          :internet_gateway_id => 'igw-123',
        }
        ec2.client.stub(:create_internet_gateway).and_return(create_response)

        create_sg_response.data[:group_id] = 'group-id'
        ec2.client.stub(:create_security_group).and_return(create_sg_response)

        create_subnet_response.data[:subnet] = subnet_details
        ec2.client.stub(:create_subnet).and_return(create_subnet_response)

        create_route_response.data[:route_table] = route_details
        ec2.client.stub(:create_route_table).and_return(create_route_response)
      end

      it 'create subnet and route' do
        vpc_config = {"vpc" => {"vpc_subnet" => "10.0.0.0/16",
            "subnets" => [{"subnet_addr" => "10.0.0.0/24",
                            "availability_zone" => "ap-northeast-1a"},
                          {"subnet_addr" => "10.0.0.1/24",
                            "availability_zone" => "ap-northeast-1b"},
                          {"subnet_addr" => "10.0.0.2/24",
                            "availability_zone" => "ap-northeast-1c"}]}}

        ec2.client.should_receive(:create_vpc).
          with(:cidr_block => '10.0.0.0/16', :instance_tenancy => 'default').
          and_return(create_vpc_response)

        ec2.client.should_receive(:create_internet_gateway).
          with(no_args).and_return(create_response)

        ec2.client.should_receive(:attach_internet_gateway).
          with(:internet_gateway_id => 'igw-123',
               :vpc_id => 'vpc-12345').and_return(attach_response)

        ec2.client.should_receive(:create_subnet)
        ec2.client.should_receive(:create_route_table)

        ec2.client.should_not_receive(:create_security_group)

        vpcf = AWS::VPCFactory.new ec2
        vpcf.create(vpc_config)
      end
    end

    describe 'makes vpc and ig and security_gateway' do
      let(:create_response) { ec2.client.stub_for(:create_internet_gateway) }
      let(:attach_response) { ec2.client.stub_for(:attach_internet_gateway) }
      let(:create_sg_response) { ec2.client.stub_for(:create_security_group) }
      let(:create_subnet_response) { ec2.client.stub_for(:create_subnet) }
      let(:create_route_response) { ec2.client.stub_for(:create_route_table) }

      let(:subnet_details) {{
          :subnet_id => 'subnet-12345',
          :vpc_id => 'vpc-12345',
          :state => 'pending',
          :cidr_block => '192.0.0.0/16',
          :available_ip_address_count => 50,
          :availability_zone => 'us-east-1c',
        }}

      let(:route_details) {{
          :route_table_id => 'rt-123',
          :vpc_id => 'vpc-12345',
        }}

      before(:each) do
        create_response.data[:internet_gateway] = { 
          :internet_gateway_id => 'igw-123',
        }
        ec2.client.stub(:create_internet_gateway).and_return(create_response)

        create_sg_response.data[:group_id] = 'group-id'
        ec2.client.stub(:create_security_group).and_return(create_sg_response)

        create_subnet_response.data[:subnet] = subnet_details
        ec2.client.stub(:create_subnet).and_return(create_subnet_response)

        create_route_response.data[:route_table] = route_details
        ec2.client.stub(:create_route_table).and_return(create_route_response)
      end

      it 'create all' do
        vpc_config = {"vpc" => {"vpc_subnet" => "10.0.0.0/16",
                        "subnets" => [{"subnet_addr" => "10.0.0.0/24",
                            "availability_zone" => "ap-northeast-1a"},
                          {"subnet_addr" => "10.0.0.1/24",
                            "availability_zone" => "ap-northeast-1b"},
                          {"subnet_addr" => "10.0.0.2/24",
                            "availability_zone" => "ap-northeast-1c"}],
            "security_group" => [{"name" =>"abc",
                                   "description" => "NAT"},
                                 {"name" =>"def",
                                   "description" => "WEB"},
                                 {"name" =>"ghi",
                                   "description" => "DB"},
                                ]}}

        ec2.client.should_receive(:create_vpc).
          with(:cidr_block => '10.0.0.0/16', :instance_tenancy => 'default').
          and_return(create_vpc_response)

        ec2.client.should_receive(:create_internet_gateway).
          with(no_args).and_return(create_response)

        ec2.client.should_receive(:attach_internet_gateway).
          with(:internet_gateway_id => 'igw-123',
               :vpc_id => 'vpc-12345').and_return(attach_response)

        ec2.client.should_receive(:create_subnet)
        ec2.client.should_receive(:create_route_table)

        ec2.client.should_receive(:create_security_group)

        vpcf = AWS::VPCFactory.new ec2
        vpcf.create(vpc_config)
      end
    end
  end
end
