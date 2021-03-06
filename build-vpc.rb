require 'aws-sdk'
require 'byebug'

#
#  Script to execute the steps in http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-subnets-commands-example.html
#
# API reference - http://docs.aws.amazon.com/sdk-for-ruby/v3/api/index.html
#
# prereq - the user has already done 'aws configure' and the authenticated user has sufficient rights
# to configure a VPC

class VpcBuilder
  def initialize
    self.ec2resource=(Aws::EC2::Resource.new(region: self.defaultRegion()))

  end

  def ec2client
    return self.ec2resource.client
  end

  def createBasicVpc(cidrBlock,tags)

    newVpc = self.ec2resource.create_vpc({cidr_block: cidrBlock})
    self.vpc=(newVpc)
    self.vpc.modify_attribute({enable_dns_support: {value: true}})
    self.vpc.modify_attribute({enable_dns_hostnames: {value: true}})
    self.vpc().create_tags({tags: tags})

    puts "created vpc with id " + self.vpc().id

    return newVpc

  end

  def createSubnet(cidrBlock,tags)

    subnet = self.ec2resource.create_subnet(
    {vpc_id: self.vpc.id,
      cidr_block: cidrBlock,
      availability_zone: self.defaultAZ})

    puts "created subnet with id " + subnet.id
    subnet.create_tags({tags: tags})
    return subnet

  end

  def createInternetGateway(tags)

    gw = self.ec2resource.create_internet_gateway
    gw.attach_to_vpc(vpc_id: self.vpc().id)
    puts "created internet gateway " + gw.id

    gw.create_tags({tags: tags})

    self.igw=(gw)
    return gw

  end

  def makeSubnetPublic

    table = self.ec2resource.create_route_table({vpc_id: self.vpc.id})
    #   table.create_tags({tags: tags})
    table.create_route({destination_cidr_block: '0.0.0.0/0', gateway_id: self.igw.id})
    table.associate_with_subnet({subnet_id: self.publicSubnet.id})

    puts "created table with id " + table.id

  end

  def createSecurityGroupForSSH

    #ec2client = Aws::EC2::Client.new(region: self.defaultRegion)
    sgName = 'SSHAccess'

    sg = self.findSecurityGroupNamed(sgName)
    if (sg)
      puts "found security group " + sg.to_s
    else
      begin
        sg = self.ec2client().create_security_group(
          {group_name: sgName,
            description: 's.g. for ' + sgName,
            vpc_id: self.vpc.id})

        self.ec2client().authorize_security_group_ingress({
          group_id: sg.group_id,
          ip_permissions: [self.sshPermissions]
        })

        puts("created security group #{sg.group_id}\n")

      rescue Aws::EC2::Errors::InvalidGroupDuplicate
        puts "A security group with the name '#{sgName}' already exists."
      end
    end
  end

  def findSecurityGroupNamed(sgName)

    begin
      result = self.ec2client().describe_security_groups({
        filters: [
        { name: "vpc-id", values: [self.vpc.id]},
        { name: "group-name", values: [sgName]} ]
      })
    rescue Aws::EC2::Errors::InvalidGroupNotFound
      result = []
      puts "exception raised - InvalidGroupNotFound"

    end

    return result.security_groups.detect { | g | g.vpc_id == self.vpc.id &&  g.group_name == sgName }


  end

  def createNATGateway(tags)
    # allocate an elastic IP
    # create a NET gw with the public subnet and elastic IP
    # add a new route to point internet traffic 0.0.0.0/0 to the NAT gw
    # update route table of private subnet.


    # allocate the elastic IP
    allocate_address_result = self.ec2client().allocate_address(domain: 'vpc')

    # create a NAT gw with the public subnet and elastic IP
    # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/EC2/Client.html#create_nat_gateway-instance_method
    # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

    resp = self.ec2client().create_nat_gateway({
      allocation_id: allocate_address_result.allocation_id,
      subnet_id: self.publicSubnet().subnet_id,
    })

    nat_gateway_id = resp.nat_gateway.nat_gateway_id

    # have to wait until it's ready
    # resp.nat_gateway.state #=> String, one of "pending", "failed",
    #       "available", "deleting", "deleted"

    puts("initializing NAT gw #{nat_gateway_id}, waiting until available\n")
    # time now
    start = Time.now.to_i


    begin
      self.ec2client.wait_until(:nat_gateway_available, nat_gateway_ids: [nat_gateway_id])
    rescue Aws::Waiters::Errors::WaiterFailed
      # resource did not enter the desired state in time
      puts("waited for NAT gw #{nat_gateway_id} but it did not complete in time")
      exit
    end


    # gw_status = nil
    # # loop until NAT gw is available
    # while (!(gw_status && gw_status.state == "available"))
    #   sleep(10)  # need something better
    #   resp = self.ec2client.describe_nat_gateways({
    #     filter: [
    #       {name: "nat-gateway-id",values: [nat_gateway_id]},
    #       {name: "vpc-id",values: [self.vpc.id]}
    #     ]})
    #     gw_status = resp.nat_gateways.detect { | gw | gw.nat_gateway_id == nat_gateway_id}
    #     puts("#{nat_gateway_id} status is #{gw_status.state}\n")
    #
    # end


    finish = Time.now.to_i
    puts("#{finish-start} seconds to create NAT gw\n")

    new_table = self.ec2resource().create_route_table({vpc_id: self.vpc.id})
    puts ("created route table #{new_table.id}\n")

    new_table.create_route({
      destination_cidr_block: "0.0.0.0/0",  # internet
      gateway_id: nat_gateway_id
    })

    puts("associating route table to subnet\n")
    assoc = new_table.associate_with_subnet({subnet_id: self.privateSubnet().id})
    #puts("created: #{resp[:association_id]}\n")
    puts("created association: #{assoc.id}\n")

  end

  def sshPermissions
    return {
      ip_protocol: "tcp",
      from_port: 22,
      to_port: 22,
      ip_ranges: [{cidr_ip: "0.0.0.0/0"}]
    }
  end

  def defaultRegion
    return 'us-east-1'
  end

  def defaultAZ
    return 'us-east-1a'
  end

  attr_accessor :ec2resource,
  #:ec2client ,
    :vpc, :igw,
    :publicSubnet, :privateSubnet, :sshSecurityGroup

end

# Step 0
# things to parameterize on command line:
#  vpc name, region, defaultAZ, key for instances

# Step 1
name = 'pmrVpc'
builder = VpcBuilder.new()
builder.createBasicVpc('10.0.0.0/16', [{key: 'Name', value: name}])

# was "Key=Name,Value=pmrVpc"
# [{key: 'Name', value: 'pmrVpc'}]

obj = builder.createSubnet('10.0.1.0/24',
  [
    {key: 'Visibility' ,value: 'Public'},
    {key: 'Name', value: "#{name}-public"}
    ])
#subnet = obj['Subnet']
builder.publicSubnet=(obj)

obj = builder.createSubnet('10.0.2.0/24',
  [
    {key: 'Visibility' ,value: 'Private'},
    {key: 'Name', value: "#{name}-private"}
  ])
#subnet = obj['Subnet']
builder.privateSubnet=(obj)

# Step 2

builder.createInternetGateway([{key: 'Name', value: name}])
# builder.attachInternetGateway()

# Step 3

builder.makeSubnetPublic()
builder.createSecurityGroupForSSH()

# Step 4
# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

builder.createNATGateway([{key: 'Name', value: name}])

# create ec2 instances in each subnet?
