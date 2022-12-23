provider "aws"{
    region = "us-east-1"
}

variable vpc_cidr_block{}
variable subnet_cidr_block{}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

resource "aws_vpc" "myapp-vpc"{
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1"{
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id

    tags = { 
        Name: "${var.env_prefix}-igw"
    }
}

/*route within the vpc is created automatically*/
/*resource "aws_route_table" "myapp-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id


    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }

    tags = {
        Name: "${var.env_prefix}-rtb"
    }
}*/


/*resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}*/



/*in this way subnetes that are not explicitly associated
 to any route table  will be automatically to main route table
 */

resource "aws_default_route_table" "main-rtb"{
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

        route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }

    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}


# resource "aws_security_group" "myapp-sg"{
#     name = "myapp-sg"
#     vpc_id = aws_vpc.myapp-vpc.id

#     /*Rules*/

#     /*for incomming trafic*/ 
#     ingress {
#         /*it can be a range*/
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         /*source*/
#         cidr_blocks = [var.my_ip]
#     }

#        ingress {
#         /*it can be a range*/
#         from_port = 8080
#         to_port = 8080
#         protocol = "tcp"
#         /*source*/
#         cidr_blocks = ["0.0.0.0/0"]
#     }

#         /*for exiting traffic*/
#         /*for installation ,fetch docker image*/
#         egress {
#         /*it can be a range*/
#             from_port = 0
#             to_port = 0
#             protocol = "-1" /*any protocol*/
#             /*source*/
#             cidr_blocks = ["0.0.0.0/0"] 
#             prefix_list_ids = [] /*for allowing access to vpc endpoints */
#         }

#     tags = {
#         Name: "${var.env_prefix}-sg"
#     }
# }


/*Syntax of using default SG instead of creating a new one */

resource "aws_default_security_group" "default-sg"{
    vpc_id = aws_vpc.myapp-vpc.id

    /*Rules*/

    /*for incomming trafic*/ 
    ingress {
        /*it can be a range*/
        from_port = 22
        to_port = 22
        protocol = "tcp"
        /*source*/
        cidr_blocks = [var.my_ip]
    }

       ingress {
        /*it can be a range*/
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        /*source*/
        cidr_blocks = ["0.0.0.0/0"]
    }

        /*for exiting traffic*/
        /*for installation ,fetch docker image*/
        egress {
        /*it can be a range*/
            from_port = 0
            to_port = 0
            protocol = "-1" /*any protocol*/
            /*source*/
            cidr_blocks = ["0.0.0.0/0"] 
            prefix_list_ids = [] /*for allowing access to vpc endpoints */
        }

    tags = {
        Name: "${var.env_prefix}-default-sg"
    } 
}

/*fetch the existing ressource ,Query ressource from aws */

data "aws_ami" "latest-amazon-linux-image" {
   most_recent = true 
   owners = ["amazon"]
   /*filtes : define the criteria for this query*/
   /*we can define multiple filter*/
   filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
   }
   filter {
        name = "virtualization-type"
        values = ["hvm"]
   }
}

output "aws_ami"{
    value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip"{
    value = aws_instance.myapp-server.public_ip
}



resource "aws_key_pair" "ssh-key"{
    key_name = "server-key"
    /*We need to provide the public so aws can create public private key pair out of that public key*/
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
    /*can be differnt accross region and it can dynamically change ==> set ami dynamically */
    /*Required*/
        ami = data.aws_ami.latest-amazon-linux-image.id
        instance_type = var.instance_type 
    /*Optional if we dont specifie the m default component will be used*/
        subnet_id = aws_subnet.myapp-subnet-1.id
        vpc_security_group_ids = [aws_default_security_group.default-sg.id]
        availability_zone = var.avail_zone
        
        associate_public_ip_address = true

        /*Not very optimal to create it manually ! */
        key_name = aws_key_pair.ssh-key.key_name
    /*It's like an entrypoint script that get executed when in ec2 insatnce whenver the servrer instanciated */
        user_data = file("entry-script.sh")
       
        tags = {
          Name: "${var.env_prefix}-server"
        } 


}

/*Automate as much as possible */
/*you may forget components when it's time to clean up  so we need to create stuff manually */
/*environment replication if create some stuff manually it make it difficult to remember steps to   replicate  */

/* Execute command in the time of creation of an ec2 insatnce */