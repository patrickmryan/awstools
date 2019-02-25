#require 'aws-sdk-ec2client'  # v2: require 'aws-sdk'
require 'aws-sdk'

# allocate an elastic IP
# create a NET gw with the public subnet and elastic IP
# get the route table of private subnet.
# add a new route to point internet traffic 0.0.0.0/0 to the NAT gw

region = "us-east-1"
vpcId = "vpc-0a6242c9cc8517576"
privateSubnetId = "subnet-0f8ce93f99667a687"
publicSubnetId  = "subnet-014b2d15eeb9bef65"


ec2client = Aws::EC2::Client.new(region: region)

instance_id = "i-0116dc3c6de929698" # For example, "i-0a123456b7c8defg9"

def display_addresses(ec2client, instance_id)
  describe_addresses_result = ec2client.describe_addresses({
    filters: [
      {
        name: "instance-id",
        values: [ instance_id ]
      },
    ]
  })
  if describe_addresses_result.addresses.count == 0
    puts "No addresses currently associated with the instance."
  else
    describe_addresses_result.addresses.each do |address|
      puts "=" * 10
      puts "Allocation ID: #{address.allocation_id}"
      puts "Association ID: #{address.association_id}"
      puts "Instance ID: #{address.instance_id}"
      puts "Public IP: #{address.public_ip}"
      puts "Private IP Address: #{address.private_ip_address}"
    end
  end
end

#puts "Before allocating the address for the instance...."
#display_addresses(ec2client, instance_id)

# allocate an elastic IP

puts "\nAllocating the address..."
allocate_address_result = ec2client.allocate_address({
  domain: "vpc"
})

# puts "allocate address result\n"
# puts(allocate_address_result.to_s)
# puts("\n")

#puts "\nAfter allocating the address for instance, but before associating the address with the instance..."
#display_addresses(ec2client, instance_id)


# create a NAT gw with the public subnet and elastic IP
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/EC2/Client.html#create_nat_gateway-instance_method
# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

resp = ec2client.create_nat_gateway({
  allocation_id: allocate_address_result.allocation_id,
  subnet_id: publicSubnetId,
})

# get the route table of private subnet.
# add a new route to point internet traffic 0.0.0.0/0 to the NAT gw

# need to get network interface ID for public subnet
# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/EC2/Client.html#describe_subnets-instance_method
resp = ec2client.describe_subnets({
  filters: [
    {
      name: "vpc-id", values: [vpcId]
    }
  ]
})

# for subnet in resp[:subnets]
#   puts subnet.to_s
#   puts("\n")
# end

subnet = (resp[:subnets]).detect{ |net| net[:subnet_id] == privateSubnetId}
puts subnet.to_s
puts("\n")

exit

# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/EC2/Client.html#describe_network_interfaces-instance_method

# puts "\nAssociating the address with the instance..."
# associate_address_result = ec2client.associate_address({
#   allocation_id: allocate_address_result.allocation_id,
#   #instance_id: instance_id,
#   network_interface_id:
# })


exit

#
# puts "\nAfter associating the address with the instance, but before releasing the address from the instance..."
# display_addresses(ec2client, instance_id)
#
# puts "\nReleasing the address from the instance..."
# ec2client.release_address({
#   allocation_id: allocate_address_result.allocation_id,
# })
#
# puts "\nAfter releasing the address from the instance..."
# display_addresses(ec2client, instance_id)
