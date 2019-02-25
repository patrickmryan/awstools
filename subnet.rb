require 'aws-sdk'

# allocate an elastic IP
# create a NET gw with the public subnet and elastic IP
# get the route table of private subnet.
# add a new route to point internet traffic 0.0.0.0/0 to the NAT gw

region = "us-east-1"
vpcId = "vpc-0a6242c9cc8517576"
privateSubnetId = "subnet-0f8ce93f99667a687"
publicSubnetId  = "subnet-014b2d15eeb9bef65"
nat_gw = "nat-00d0acc6af2e83bd9"



ec2client = Aws::EC2::Client.new(region: region)



resp = ec2client.describe_subnets({
  filters: [
    {
      name: "vpc-id", values: [vpcId]
    }
  ]
})

subnet = (resp[:subnets]).detect{ |net| net[:subnet_id] == privateSubnetId}
#puts subnet.to_s
#puts("\n")

# puts("getting all route tables\n")
# resp = ec2client.describe_route_tables({
#   filters: [
#     {
#       name: "vpc-id", values: [vpcId]
#     }
#   ],
#   dry_run: false,
#
#   max_results: 50,
# })

# puts resp.to_s
# exit

# n=1
# (resp[:route_tables]).each { |t|
#   #puts("#{n}\n")
#   puts t.to_s
#   puts("\n")
#   n=n+1
# }

puts "looking for rt for subnet #{privateSubnetId}\n"

# table = (resp[:route_tables]).detect{|t| t[:subnet_id] == privateSubnetId}

# puts("#{privateSubnetId}\n")
# subnetRouteTable = nil
# (resp[:route_tables]).each { | table |
#   subnet = table.associations.detect { |assoc|
#     puts(" -- #{assoc[:route_table_id]} #{assoc[:subnet_id]} main: #{assoc[:main]}\n")
#     assoc[:subnet_id] == privateSubnetId }
#   if (subnet)
#      subnetRouteTable = table
#   end
# }
#
# if (subnetRouteTable)
#     puts("found route table for subnet\n")
#     puts subnetRouteTable.to_s
# else
#     puts "did not find route table\n"
# end

# look for rt for subnet. if found, use it
# if missing, then it uses the VPC subnet. need to copy the VPC subnet,
# add a new route, and the associate it to the subnet

# this is stupid. just create a new route table, add a route to the NATgw and
# associate it with the private subnet.
# maybe copy the VPC's default route table

# create_route_table

aKey = "Name"
aValue = "test-route-to-internet"

puts("creating route table\n")
new_table = ec2client.create_route_table({vpc_id: vpcId})
puts("created:\n")
puts new_table.to_s
puts("\n")

ec2client.create_tags({
  resources: [(new_table.route_table[:route_table_id])],
  tags: [{key: aKey, value: aValue}]})

# create_route

puts("creating route to nat-gw\n")
resp = ec2client.create_route({
  destination_cidr_block: "0.0.0.0/0",  # internet
  gateway_id: nat_gw,
  route_table_id: (new_table.route_table[:route_table_id]),
})
puts("created:\n")
puts resp.to_s
puts("\n")

# need to first disassociate the private subnet from the default
# route table

resp = ec2client.describe_route_tables({
  filters: [
    { name: "vpc-id", values: [vpcId]},
    { name: "association.subnet-id", values: [privateSubnetId]}
  ],
})
puts("route table info:\n")
puts resp.to_s
puts("\n")

# find the association between the private subnet and the default route
assoc = nil
for table in resp.route_tables.each
  a = table.associations.detect { | a | a.subnet_id == privateSubnetId }
  if (a)
    assoc = a
  end
end

# disassociate
resp = ec2client.disassociate_route_table({
  association_id: (assoc.route_table_association_id)
})

# associate to subnet

puts("associating new route table with private subnet\n")
resp = ec2client.associate_route_table({
  route_table_id: (new_table.route_table[:route_table_id]),
  subnet_id: privateSubnetId})
puts("created:\n")
puts resp.to_s
puts("\n")


# https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/EC2/Client.html#create_route_table-instance_method
