resource "aws_eks_addon" "efs_csi" {
  cluster_name                = var.eks_cluster_name
  addon_name                  = "aws-efs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.nodes,
  ]
}

