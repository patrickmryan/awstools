require 'json'

#
#  Script to execute the steps in http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-subnets-commands-example.html
#
#
# prereq - the user has already done 'aws configure' and the authenticated user has sufficient rights
# to configure a VPC

class VpcBuilder
  def createBasicVpc(cidrBlock,tags)
    # create the VPC
    obj = self.executeAndParse("aws ec2 create-vpc --cidr-block #{cidrBlock}")
 
    vpc = obj['Vpc']
    id = vpc['VpcId']
    self.vpcId=(id)
    
    # add the tags
    self.execute("aws ec2 create-tags --resources #{self.vpcId} --tags #{tags}")
          
    # return the full JSON doc
    return obj
  end

  def createSubnet(cidrBlock,tags)
    obj = self.executeAndParse("aws ec2 create-subnet --vpc-id #{self.vpcId} --cidr-block #{cidrBlock}")
       
    subnet = obj['Subnet']
    id = subnet['SubnetId']
      
    #self.publicSubnetId=(subnet['SubnetId'])
    #puts "publicSubnetId = " + publicSubnetId
    self.execute("aws ec2 create-tags --resources #{id} --tags #{tags}")
    return obj
  end
  
  def createInternetGateway
    obj = self.executeAndParse("aws ec2 create-internet-gateway")
    gw = obj['InternetGateway']
    self.internetGatewayId=(gw["InternetGatewayId"])
    return obj
  end
  
  def attachInternetGateway
    self.execute(
    "aws ec2 attach-internet-gateway --vpc-id #{self.vpcId} " +
    "--internet-gateway-id #{self.internetGatewayId}")
  end
  
  def makeSubnetPublic
    obj = self.executeAndParse("aws ec2 create-route-table --vpc-id #{self.vpcId}")
    table = obj['RouteTable']
    self.routeTableId=(table['RouteTableId'])

    self.execute("aws ec2 create-route --route-table-id #{self.routeTableId} "+
    "--destination-cidr-block 0.0.0.0/0 --gateway-id #{self.internetGatewayId}")

    # this just confirms that the above worked
    #obj = self.executeAndParse("aws ec2 describe-route-tables --route-table-id #{self.routeTableId}")
    #return obj
    
    self.execute("aws ec2 associate-route-table --subnet-id #{self.publicSubnetId} --route-table-id #{self.routeTableId}")  
    self.execute("aws ec2 modify-subnet-attribute --subnet-id #{self.publicSubnetId} --map-public-ip-on-launch")
    
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
  
  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId, :internetGatewayId, :routeTableId, :sshSecGroupId
  
end

# Step 1

builder = VpcBuilder.new()
builder.createBasicVpc('10.0.0.0/16',"Key=Name,Value=pmrVpc")

obj = builder.createSubnet('10.0.1.0/24','Key=Visibility,Value=Public')
subnet = obj['Subnet']
builder.publicSubnetId=(subnet['SubnetId'])

obj = builder.createSubnet('10.0.2.0/24','Key=Visibility,Value=Private')
subnet = obj['Subnet']
builder.privateSubnetId=(subnet['SubnetId'])


# Step 2

builder.createInternetGateway()
builder.attachInternetGateway()

# Step 3

builder.makeSubnetPublic()
builder.createSecurityGroupForSSH()

# still need to at NAT gateway to provide way out to Internet for private subnet

