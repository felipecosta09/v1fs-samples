# resource "aws_ecs_cluster" "ecs_cluster" {
#   name = "${var.prefix}-ecs-cluster-${random_string.random.id}"
#   tags = {
#     Name = "${var.prefix}-ecs-cluster-${random_string.random.id}"
#   }
# }

# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "ecs_task_execution_role"

#   assume_role_policy = jsonencode({
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ecs-tasks.amazonaws.com"
#       }
#     }]
#     Version = "2012-10-17"
#   })
# }

# resource "aws_iam_role_policy_attachment" "efs_role_policy_attach" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
# }

# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# resource "aws_ecs_task_definition" "ecs_task_definition" {
#   family                   = "${var.prefix}-task-definition-${random_string.random.id}"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "1024"
#   memory                   = "2048"
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
#   runtime_platform {
#     operating_system_family = "LINUX"
#     cpu_architecture = "X86_64"
#   }
#   container_definitions = jsonencode([{
#     name  = "${var.prefix}-container-${random_string.random.id}"
#     image = "nginx:latest"
#     portMappings = [{
#       containerPort = 80
#       hostPort      = 80
#       protocol      = "tcp"
#     }]
#     mountPoints = [
#         {
#           sourceVolume  = "efs-volume"
#           containerPath = "/usr/share/nginx/html"
#           readOnly      = false
#         },
#       ]
#   }])
#   volume {
#     name = "efs-volume"

#     efs_volume_configuration {
#       file_system_id = var.efs_id
#       root_directory = var.efs_mount_point

#       authorization_config {
#         access_point_id = var.efs_access_point
#         iam             = "ENABLED"
#       }

#       transit_encryption      = "ENABLED"
#       transit_encryption_port = 2049
#     }
#   }
#   tags = {
#     Name = "${var.prefix}-task-definition-${random_string.random.id}"
#   }
# }

# resource "aws_ecs_service" "ecs_service" {
#   name            = "${var.prefix}-ecs-service-${random_string.random.id}"
#   cluster         = aws_ecs_cluster.ecs_cluster.id
#   task_definition = aws_ecs_task_definition.ecs_task_definition.arn
#   desired_count   = 5
#   launch_type     = "FARGATE"

#   network_configuration {
#     assign_public_ip = false
#     subnets          = ["subnet-02808a1cd817ad9f3"] # Replace with your subnet id
#     security_groups  = ["sg-035cdb137ef183a8b"]     # Replace with your security group id
#   }
# }