require 'json'
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
    resource = Aws::EC2::Resource.new(region: self.region())
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
      availability_zone: self.az})

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

    ec2client = Aws::EC2::Client.new(region: self.region)
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

    result = ec2client.describe_security_groups
    
    puts "found security groups:"
    puts "---"
    result.security_groups.each { |g| puts "#{g.group_id} -> #{g.group_name}" }
    puts "---"
    
    return result.security_groups.detect { | g | g.vpc_id == self.vpc.id &&  g.group_name == sgName }

    #    obj = self.executeAndParse("aws ec2 describe-security-groups --filters Name=vpc-id,Values=#{self.vpcId}")
    #    groups = obj['SecurityGroups']
    #    target = groups.detect { | g | g['GroupName'] == sgName }
    #
    #    return target  # might be nil

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

  def region
    return 'us-east-1'
  end

  def az
    return 'us-east-1a'
  end

#  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId, :internetGatewayId, :routeTableId, :sshSecGroupId
  attr_accessor :ec2resource, :vpc, :igw, :publicSubnet, :privateSubnet, :sshSecurityGroup

end

# Step 1

builder = VpcBuilder.new()
builder.createBasicVpc('10.0.0.0/16', [{key: 'Name', value: 'pmrVpc'}])

# was "Key=Name,Value=pmrVpc"
# [{key: 'Name', value: 'pmrVpc'}]

obj = builder.createSubnet('10.0.1.0/24',[{key: 'Visibility' ,value: 'Public'}])
#subnet = obj['Subnet']
builder.publicSubnet=(obj)

obj = builder.createSubnet('10.0.2.0/24',[{key: 'Visibility' ,value: 'Private'}])
#subnet = obj['Subnet']
builder.privateSubnet=(obj)

# Step 2

builder.createInternetGateway()
# builder.attachInternetGateway()

# Step 3

builder.makeSubnetPublic()
builder.createSecurityGroupForSSH()

# still need to at NAT gateway to provide way out to Internet for private subnet

