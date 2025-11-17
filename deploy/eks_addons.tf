resource "aws_eks_addon" "efs_csi" {
  cluster_name                = var.eks_cluster_name
  addon_name                  = "aws-efs-csi-driver"
  resolve_conflicts           = "OVERWRITE"
}


