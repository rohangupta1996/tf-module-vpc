resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = merge(var.tags, { Name = "${var.env}-vpc"})
}

## Peering

resource "aws_vpc_peering_connection" "peer" {
  peer_owner_id = data.aws_caller_identity.account.account_id
  peer_vpc_id   = var.default_vpc_id
  vpc_id        = aws_vpc.main.id
  auto_accept   = true
  tags = merge(
    var.tags,
    { Name = "${var.env}-peer" }
  )
}

## public subnet
 resource "aws_subnet" "public_subnet" {
   vpc_id            = aws_vpc.main.id

   for_each          = var.public_subnet
   cidr_block        = each.value["cidr_block"]
   availability_zone = each.value["availability_zone"]
   tags = merge(
     var.tags,
     { Name = "${var.env}-${each.value["name"]}" }
   )

 }

## Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.tags,
    { Name = "${var.env}-igw" }
  )
}

## NAT gateway

resource "aws_eip" "nat" {
  for_each = var.public_subnet
  vpc      = true
}

resource "aws_nat_gateway" "nat-gateway" {
  for_each = var.public_subnet
  allocation_id = aws_eip.nat[each.value["name"]].id
  subnet_id     = aws_subnet.public_subnet[each.value["name"]].id

  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )
}

## public route table

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  route {
    cidr_block = data.aws_vpc.default_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }


  for_each          = var.public_subnet
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )

}

resource "aws_route_table_association" "public-association" {
  for_each       = var.public_subnet
  subnet_id      = lookup(lookup(aws_subnet.public_subnet, each.value["name"], null ), "id", null )
  #subnet_id     = aws_subnet.public_subnet[each.value["name"]].id
  route_table_id = aws_route_table.public-route-table[each.value["name"]].id
}

## private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id

  for_each          = var.private_subnet
  cidr_block        = each.value["cidr_block"]
  availability_zone = each.value["availability_zone"]
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )

}

## private route table

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id
  for_each          = var.private_subnet
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway["public-${split("-",each.value["name"])[1]}"].id
  }
  route {
    cidr_block = data.aws_vpc.default_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )

}

resource "aws_route_table_association" "private-association" {
  for_each       = var.private_subnet
  subnet_id      = lookup(lookup(aws_subnet.private_subnet, each.value["name"], null ), "id", null )
  #subnet_id     = aws_subnet.public_subnet[each.value["name"]].id
  route_table_id = aws_route_table.private-route-table[each.value["name"]].id
}

## Route to the default VPC for peering to work

resource "aws_route" "route" {
  route_table_id            = var.default_route_table
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}