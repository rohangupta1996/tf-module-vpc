resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = merge(var.tags, { Name = "${var.env}-vpc"})
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

## public route table

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id


  for_each          = var.public_subnet
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )

}

resource "aws_route_table_association" "public-association" {
  for_each       = var.public_subnet
  subnet_id      = aws_subnet.public_subnet[each.value["name"]].id
  route_table_id = aws_route_table.[each.value["name"]].id
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
  tags = merge(
    var.tags,
    { Name = "${var.env}-${each.value["name"]}" }
  )

}