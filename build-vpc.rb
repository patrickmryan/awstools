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
  
  def executeAndParse(cmd)
    text = self.execute(cmd)
    return JSON.parse(text)
    
  end
  def execute(cmd)
    puts cmd
    return `#{cmd}`
  end
  
  attr_accessor :vpcDoc, :publicSubnetDoc, :privateSubnetDoc
  attr_accessor :vpcId, :publicSubnetId, :privateSubnetId
  
end


builder = VpcBuilder.new()
obj = builder.createBasicVpc('10.0.0.0/16',"Key=Name,Value=pmrVpc")
puts obj

obj = builder.createSubnet('10.0.1.0/24','Key=Visibility,Value=Public')
puts obj

obj = builder.createSubnet('10.0.2.0/24','Key=Visibility,Value=Private')
puts obj


exit


# create the VPC 
cmd = 'aws ec2 create-vpc --cidr-block 10.0.0.0/16'
# undo = aws ec2 delete-vpc --vpc-id {vpc id}
puts cmd
result = `#{cmd}`
puts result
puts "exit code = " + $?.to_s
obj = JSON.parse(result)
# puts obj
vpc = obj['Vpc']
vpcId = vpc['VpcId']
puts vpcId

cmd = "aws ec2 create-tags --resources #{vpcId} --tags Key=Name,Value=pmrVpc"
puts cmd
`#{cmd}`

# create the public subnet
cmd = "aws ec2 create-subnet --vpc-id #{vpcId} --cidr-block 10.0.1.0/24"
puts cmd
result = `#{cmd}`
obj = JSON.parse(result)
subnet = obj['Subnet']
publicSubnetId = subnet['SubnetId']
puts "publicSubnetId = " + publicSubnetId
cmd = "aws ec2 create-tags --resources #{publicSubnetId} --tags Key=Visibility,Value=Public"
puts cmd
`#{cmd}`

## create the private subnet
#cmd = "aws ec2 create-subnet --vpc-id #{vpcId} --cidr-block 10.0.2.0/24"
#puts cmd
#result = `#{cmd}`
#subnet = JSON.parse(result)
#privateSubnetId = result['Subnet']['SubnetId']
#puts "privateSubnetId = " + publicSubnetId
#cmd = "aws ec2 create-tags --resources #{privateSubnetId} --tags Key=Visibility,Value=Private"
#puts cmd
#`#{cmd}`


