require 'json'

# prereq - the user has already done 'aws configure' and the authenticated used has sufficient rights
# to configure a VPC


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

cmd = 'aws ec2 create-tags --resources #{vpcId} --tags Key=Name,Value=pmrVpc'
puts cmd
`#{cmd}`

