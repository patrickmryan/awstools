require 'json'
require 'aws-sdk'

#
#  Script to execute the steps in http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-subnets-commands-example.html
#
#
# prereq - the user has already done 'aws configure' and the authenticated user has sufficient rights
# to configure a VPC

class VpcBuilder
  def createBasicVpc(cidrBlock,tags)
    resource = Aws::EC2::Resource.new(region: self.region())
    self.ec2=(resource)
    newVpc = self.ec2.create_vpc({cidr_block: cidrBlock})
    self.vpc=(newVpc)
    self.vpc.modify_attribute({enable_dns_support: {value: true}})
    self.vpc.modify_attribute({enable_dns_hostnames: {value: true}})
    self.vpc().create_tags({tags: tags})
    
    puts "created vpc with id " + self.vpc().id
    
    return newVpc
    
#    # create the VPC
#    obj = self.executeAndParse("aws ec2 create-vpc --cidr-block #{cidrBlock}")
# 
#    vpc = obj['Vpc']
#    id = vpc['VpcId']
#    self.vpcId=(id)
#    
#    # add the tags
#    self.execute("aws ec2 create-tags --resources #{self.vpcId} --tags #{tags}")
#          
#    # return the full JSON doc
#    return obj
#    
  end

  def createSubnet(cidrBlock,tags)
    
    subnet = self.ec2.create_subnet(
      {vpc_id: self.vpc.id, 
        cidr_block: cidrBlock, 
        availability_zone: self.az})
    subnet.create_tags({tags: tags})
    
    puts "created subnet with id " + subnet.id
    return subnet
    
#    obj = self.executeAndParse("aws ec2 create-subnet --vpc-id #{self.vpcId} --cidr-block #{cidrBlock}")
#       
#    subnet = obj['Subnet']
#    id = subnet['SubnetId']
#      
#    #self.publicSubnetId=(subnet['SubnetId'])
#    #puts "publicSubnetId = " + publicSubnetId
#    self.execute("aws ec2 create-tags --resources #{id} --tags #{tags}")
#    return obj
    
  end
  
  def createInternetGateway
    
    gw = self.ec2.create_internet_gateway
    gw.attach_to_vpc(vpc_id: self.vpc().id)    
    puts "created internet gateway " + gw.id
    
    self.igw=(gw)
    return gw
    
#    obj = self.executeAndParse("aws ec2 create-internet-gateway")
#    gw = obj['InternetGateway']
#    self.internetGatewayId=(gw["InternetGatewayId"])
#    return obj
  end
  
#  def attachInternetGateway
#     
#    self.execute(
#    "aws ec2 attach-internet-gateway --vpc-id #{self.vpcId} " +
#    "--internet-gateway-id #{self.internetGatewayId}")
#    
#  end
  
  def makeSubnetPublic
    
    table = self.ec2.create_route_table({vpc_id: self.vpc.id})
 #   table.create_tags({tags: tags})
    table.create_route({destination_cidr_block: '0.0.0.0/0', gateway_id: self.igw.id})
    table.associate_with_subnet({subnet_id: self.publicSubnet.id})
      
    puts "created table with id " + table.id

    
#    obj = self.executeAndParse("aws ec2 create-route-table --vpc-id #{self.vpcId}")
#    table = obj['RouteTable']
#    self.routeTableId=(table['RouteTableId'])
#
#    self.execute("aws ec2 create-route --route-table-id #{self.routeTableId} "+
#    "--destination-cidr-block 0.0.0.0/0 --gateway-id #{self.internetGatewayId}")
#
#    self.execute("aws ec2 associate-route-table --subnet-id #{self.publicSubnetId} --route-table-id #{self.routeTableId}")  
#    self.execute("aws ec2 modify-subnet-attribute --subnet-id #{self.publicSubnetId} --map-public-ip-on-launch")
#    
  end

  def createSecurityGroupForSSH
    
    sgName = 'SSHAccess'
    sshGroup = self.findSecurityGroupNamed(sgName)
    if (sshGroup)
      self.sshSecGroupId=(sshGroup['GroupId'])
    else
      obj = self.executeAndParse("aws ec2 create-security-group --group-name #{sgName} " +
      "--description 'Security group for SSH access' --vpc-id #{self.vpcId}")
      self.sshSecGroupId=(obj['GroupId'])
      
    end
      
    self.execute("aws ec2 authorize-security-group-ingress --group-id #{self.sshSecGroupId} --protocol tcp --port 22 --cidr 0.0.0.0/0")  
          
  end

  def findSecurityGroupNamed(sgName)
    obj = self.executeAndParse("aws ec2 describe-security-groups --filters Name=vpc-id,Values=#{self.vpcId}")
    groups = obj['SecurityGroups']

    target = groups.detect { | g | g['GroupName'] == sgName }
    #  puts "looking for s.g. named #{sgName}, found " + target.to_s
    return target  # might be nil

  end

  def executeAndParse(cmd)
    text = self.execute(cmd)
    return JSON.parse(text)
    
  end
  def execute(cmd)
    puts cmd
    return `#{cmd}`
  end
  
  def region
    return 'us-east-1'
  end
  
  def az
    return 'us-east-1a'
  end
  
  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId, :internetGatewayId, :routeTableId, :sshSecGroupId
  attr_accessor :ec2, :vpc, :igw, :publicSubnet, :privateSubnet
  
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
#builder.createSecurityGroupForSSH()

# still need to at NAT gateway to provide way out to Internet for private subnet

