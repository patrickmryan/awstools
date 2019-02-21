## require 'json'
require 'aws-sdk'

#
#  Script to execute the steps in http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-subnets-commands-example.html
#
# API reference - http://docs.aws.amazon.com/sdk-for-ruby/v3/api/index.html
#
# prereq - the user has already done 'aws configure' and the authenticated user has sufficient rights
# to configure a VPC

class VpcBuilder
  def createBasicVpc(cidrBlock,tags)
    resource = Aws::EC2::Resource.new(region: self.defaultRegion())
    self.ec2resource=(resource)

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

  def createInternetGateway

    gw = self.ec2resource.create_internet_gateway
    gw.attach_to_vpc(vpc_id: self.vpc().id)
    puts "created internet gateway " + gw.id

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

    ec2client = Aws::EC2::Client.new(region: self.defaultRegion)
    sgName = 'SSHAccess'

    sg = self.findSecurityGroupNamed(ec2client, sgName)
    if (sg)
      puts "found security group " + sg.to_s
    end

    if (!sg)

      #      obj = self.executeAndParse("aws ec2 create-security-group --group-name #{sgName} " +
      #      "--description 'Security group for SSH access' --vpc-id #{self.vpcId}")
      #      self.sshSecGroupId=(obj['GroupId'])
      #

      begin

        result = ec2client.create_security_group(
        {group_name: sgName,
          description: 's.g. for ' + sgName,
          vpc_id: self.vpc.id})
        #self.sshSecurityGroup=(sg)

        ec2client.authorize_security_group_ingress({
          group_id: result.group_id,
          ip_permissions: [
          self.sshPermissions
          #,
          #          {
          #          ip_protocol: "tcp",
          #          from_port: 22,
          #          to_port: 22,
          #          ip_ranges: [{cidr_ip: "0.0.0.0/0"}]
          #          }
          ]
        })

        puts "created security group " + result.to_s

      rescue Aws::EC2::Errors::InvalidGroupDuplicate
        puts "A security group with the name '#{sgName}' already exists."
      end

      #    sg.authorize_egress({
      #      ip_permissions: [{
      #      ip_protocol: 'tcp',
      #      from_port: 22,
      #      to_port: 22,
      #      ip_ranges: [
      #      {cidr_ip: '0.0.0.0/0'
      #      }]
      #      }]
      #    })

      #self.execute("aws ec2 authorize-security-group-ingress --group-id #{self.sshSecGroupId} --protocol tcp --port 22 --cidr 0.0.0.0/0")
    end
  end

  def findSecurityGroupNamed(ec2client, sgName)

    begin

      result = ec2client.describe_security_groups({
        filters: [
        { name: "vpc-id", values: [self.vpc.id]},
        { name: "group-name", values: [sgName]} ]
      })

    rescue Aws::EC2::Errors::InvalidGroupNotFound
      result = []
      puts "exception raised - InvalidGroupNotFound"

    end

#    puts "found security groups:"
#    puts "---"
#    result.security_groups.each { |g| puts "#{g.group_id} -> #{g.group_name}" }
#    puts "---"

    return result.security_groups.detect { | g | g.vpc_id == self.vpc.id &&  g.group_name == sgName }

    #    obj = self.executeAndParse("aws ec2 describe-security-groups --filters Name=vpc-id,Values=#{self.vpcId}")
    #    groups = obj['SecurityGroups']
    #    target = groups.detect { | g | g['GroupName'] == sgName }
    #
    #    return target  # might be nil

  end

  def createNATGateway
    # allocate the elastic IP
    allocate_address_result = ec2resource.allocate_address(domain: 'vpc')
    # associate the address with the public subnet
    associate_address_result = ec2.associate_address(
      allocation_id: allocate_address_result.allocation_id,
      #instance_id: instance_id
      network_interface_id: ""
    )
  end


  def sshPermissions
    return {
      ip_protocol: "tcp",
      from_port: 22,
      to_port: 22,
      ip_ranges: [{cidr_ip: "0.0.0.0/0"}]
    }
  end

  #  def executeAndParse(cmd)
  #    text = self.execute(cmd)
  #    return JSON.parse(text)
  #
  #  end
  #
  #  def execute(cmd)
  #    puts cmd
  #    return `#{cmd}`
  #  end

  def defaultRegion
    return 'us-east-1'
  end

  def defaultAZ
    return 'us-east-1a'
  end

  #  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId, :internetGatewayId, :routeTableId, :sshSecGroupId
  attr_accessor :ec2resource, :vpc, :igw, :publicSubnet, :privateSubnet, :sshSecurityGroup

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

builder.createInternetGateway()
# builder.attachInternetGateway()

# Step 3

builder.makeSubnetPublic()
builder.createSecurityGroupForSSH()

# still need to add NAT gateway to provide way out to Internet for private subnet

# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

##builder.createNATGateway()

# allocate an elastic IP
# create a NET gw with the public subnet and elastic IP
# update route table of private subnet.
# add a new route to point internet traffic 0.0.0.0/0 to the NAT gw

# create ec2 instances in each subnet?
