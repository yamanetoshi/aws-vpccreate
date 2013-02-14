require 'spec_helper'

describe AWS::Vpccreate do
  let!(:config) { AWS.config.with(:stub_requests => true,
                                 :access_key_id => "AKID",
                                 :secret_access_key => 'b') }
  let!(:ec2) { AWS::EC2.new(:config => config) }
  let!(:vpcc) { AWS::Vpccreate.new(ec2) }

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

  describe 'create_vpc' do
    it 'calls #create_vpc on the client' do
      ec2.client.should_receive(:create_vpc).
        with(:cidr_block => '10.0.0.0/16', :instance_tenancy => 'default').
        and_return(create_vpc_response)

      vpcc.create_vpc('10.0.0.0/16')

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '10.0.0.0/16',
          :vpc_id => 'vpc-12345',
          :subnets => [],
          :security_group => []}}
    end

    it 'calls accept a different tenancy value' do
      ec2.client.should_receive(:create_vpc).
        with(:cidr_block => '10.0.0.0/24', :instance_tenancy => 'dedicated').
        and_return(create_vpc_response)

      vpcc.create_vpc('10.0.0.0/24', :instance_tenancy => :dedicated)

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '10.0.0.0/24',
          :vpc_id => 'vpc-12345',
          :subnets => [],
          :security_group => []}}
    end

    it 'returns a VPC object' do
      vpc = vpcc.create_vpc('192.0.0.0/16')

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '192.0.0.0/16',
          :vpc_id => 'vpc-12345',
          :subnets => [],
          :security_group => []}}

      vpc.should be_a(AWS::EC2::VPC)
      vpc.vpc_id.should == 'vpc-12345'
      vpc.cidr_block.should == '192.0.0.0/16'
#      vpc.dhcp_options_id.should == 'dopt-12345'
      vpc.instance_tenancy.should == :default
    end
  end

  describe 'create_subnet' do
    let!(:vpc) { vpcc.create_vpc('10.0.0.0/16') }

    let(:subnet_details) {{
        :subnet_id => 'subnet-12345',
        :vpc_id => 'vpc-12345',
        :state => 'pending',
        :cidr_block => '192.0.0.0/16',
        :available_ip_address_count => 50,
        :availability_zone => 'us-east-1c',
      }}

    let(:response) { ec2.client.stub_for(:create_subnet) }

    before(:each) do
      response.data[:subnet] = subnet_details
      ec2.client.stub(:create_subnet).and_return(response)
    end

    it 'vpc in vpcc is valid' do
      vpcc.vpc.should be_a(AWS::EC2::VPC)
      vpcc.vpc.id.should == 'vpc-12345'
    end

    it 'calls #create_subnet on the client' do
      ec2.client.should_receive(:create_subnet).
        with(:vpc_id => vpc.id, :cidr_block => '10.0.0.0/16').
        and_return(response)
      vpcc.create_subnet('10.0.0.0/16')

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '10.0.0.0/16',
          :vpc_id => 'vpc-12345',
          :subnets => [{:subnet_addr => '10.0.0.0/16',
                       :availability_zone => nil}],
          :security_group => []}}
    end

    it 'accepts an availability zone name' do
      ec2.client.should_receive(:create_subnet).with(
          :vpc_id => vpc.id, 
          :cidr_block => 'cidr-block',
          :availability_zone => 'abc'
       ).and_return(response)
      subnet = vpcc.create_subnet('cidr-block',
                                  :availability_zone => 'abc')

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '10.0.0.0/16',
          :vpc_id => 'vpc-12345',
          :subnets => [{:subnet_addr => 'cidr-block',
                       :availability_zone => 'abc'}],
          :security_group => []}}
    end

    it 'returns a populated subnet' do
      subnet = vpcc.create_subnet('192.0.0.0/16')

      subnet.should be_a(AWS::EC2::Subnet)
      subnet.subnet_id.should == 'subnet-12345'
      subnet.vpc_id.should == 'vpc-12345'
      subnet.cidr_block.should == '192.0.0.0/16'
      subnet.available_ip_address_count.should == 50
      subnet.availability_zone_name.should == 'us-east-1c'
    end

    it 'throw exception when object has no vpc object' do
      tmp_vpcc = AWS::Vpccreate.new(ec2)
      proc { tmp_vpcc.create_subnet('10.0.0.0/16') }.should raise_error
    end
  end

  describe 'create_ig' do
    let!(:vpc) { vpcc.create_vpc('10.0.0.0/16') }

    let(:create_response) { ec2.client.stub_for(:create_internet_gateway) }
    let(:attach_response) { ec2.client.stub_for(:attach_internet_gateway) }

    before(:each) do
      create_response.data[:internet_gateway] = { 
        :internet_gateway_id => 'igw-123',
      }
      ec2.client.stub(:create_internet_gateway).and_return(create_response)
    end

    it 'calls #create_internet_gateway on the client' do
      ec2.client.should_receive(:create_internet_gateway).
        with(no_args).and_return(create_response)
      ig = vpcc.create_ig
    end

    it 'calls #attach_internet_gateway on the client' do
      ec2.client.should_receive(:attach_internet_gateway).with(
        :internet_gateway_id => 'igw-123',
        :vpc_id => vpc.id).and_return(attach_response)
      ig = vpcc.create_ig
    end

    it 'returns an internet gateway' do
      ig = vpcc.create_ig
      ig.should be_an(AWS::EC2::InternetGateway)
      ig.internet_gateway_id.should == 'igw-123'
      ig.config.should == config
    end

    it 'throw exception when object has no vpc object' do
      tmp_vpcc = AWS::Vpccreate.new(ec2)
      proc { tmp_vpcc.create_ig }.should raise_error
    end
  end

  describe 'create_security_group' do
    let!(:vpc) { vpcc.create_vpc('10.0.0.0/16') }

    let(:response) { ec2.client.stub_for(:create_security_group) }

    before(:each) do
      response.data[:group_id] = 'group-id'
      ec2.client.stub(:create_security_group).and_return(response)
    end

    it 'calls #create_security_group on the client' do
      ec2.client.should_receive(:create_security_group).
        with(:group_name => 'abc',
             :description => 'xyz',
             :vpc_id => vpc.id).and_return(response)
      sg = vpcc.create_sg('abc', :description => 'xyz')

      vpcc.logger.config_log.should == {:vpc => {:vpc_subnet => '10.0.0.0/16',
          :vpc_id => 'vpc-12345',
          :subnets => [],
          :security_group => [{:name => 'abc', :description => 'xyz'}]}}
    end

    it 'returns an security gateway' do
      sg = vpcc.create_sg('abc', :description => 'xyz')
      sg.should be_a(AWS::EC2::SecurityGroup)
      sg.name.should == 'abc'
      sg.description.should == 'xyz'
      sg.vpc_id.should == vpc.id
    end

    it 'throw exception when object has no vpc object' do
      tmp_vpcc = AWS::Vpccreate.new(ec2)
      proc { tmp_vpcc.create_sg('name') }.should raise_error
    end
  end

  describe 'create_rt' do
    let!(:vpc) { vpcc.create_vpc('10.0.0.0/16') }

    let(:details) {{
        :route_table_id => 'rt-123',
        :vpc_id => vpc.id,
      }}

    let(:response) { ec2.client.stub_for(:create_route_table) }

    before(:each) do
      response.data[:route_table] = details
      ec2.client.stub(:create_route_table).and_return(response)
    end

    it 'calls #create_route_table on the client' do
      ec2.client.should_receive(:create_route_table).
        with(:vpc_id => vpc.id).and_return(response)

      vpcc.create_rt
    end

    it 'returns an route table' do
      rt = vpcc.create_rt
      rt.should be_a(AWS::EC2::RouteTable)
      rt.vpc.should be_a(AWS::EC2::VPC)
      rt.vpc.vpc_id.should == vpc.id
    end

    it 'throw exception when object has no vpc object' do
      tmp_vpcc = AWS::Vpccreate.new(ec2)
      proc { tmp_vpcc.create_rt(:vpc => 'vpc-id') }.should raise_error
    end
  end
end
