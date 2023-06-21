data "aws_efs_file_system" "efs" {
  file_system_id = var.efs_id
}

data "aws_efs_access_point" "efs-access-point" {
  access_point_id = var.efs_access_point
}