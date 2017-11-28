require 'json'

# prereq - the user has already done 'aws configure' and the authenticated used has sufficient rights
# to configure a VPC

class VpcBuilder
  def createBasicVpc(cidrBlock,tags)
    # create the VPC
    obj = self.executeAndParse("aws ec2 create-vpc --cidr-block #{cidrBlock}")
    self.vpcDoc=(obj)
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
    self.publicSubnetId=(subnet['SubnetId'])
    #puts "publicSubnetId = " + publicSubnetId
    self.execute("aws ec2 create-tags --resources #{self.publicSubnetId} --tags #{tags}")
    
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

  def executeAndParse(cmd)
    text = self.execute(cmd)
    return JSON.parse(text)
    
  end
  def execute(cmd)
    puts cmd
    return `#{cmd}`
  end
  
  attr_accessor :vpcDoc, :publicSubnetDoc, :privateSubnetDoc
  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId, :internetGatewayId
  
end


builder = VpcBuilder.new()
obj = builder.createBasicVpc('10.0.0.0/16',"Key=Name,Value=pmrVpc")
#puts obj

obj = builder.createSubnet('10.0.1.0/24','Key=Visibility,Value=Public')
#puts obj

obj = builder.createSubnet('10.0.2.0/24','Key=Visibility,Value=Private')
#puts obj

obj = builder.createInternetGateway()
#puts obj
builder.attachInternetGateway()


exit