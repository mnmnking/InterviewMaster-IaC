# IAM ALB CONTROLLER 
####################
module "lb_role" {
 source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

 role_name                              = "itm_eks_lb"
 attach_load_balancer_controller_policy = true

 oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
 }

 resource "kubernetes_service_account" "service-account" {
 metadata {
     name      = "aws-load-balancer-controller"
     namespace = "kube-system"
     labels = {
     "app.kubernetes.io/name"      = "aws-load-balancer-controller"
     "app.kubernetes.io/component" = "controller"
     }
     annotations = {
     "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
     "eks.amazonaws.com/sts-regional-endpoints" = "true"
     }
 }
 }

# data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"
#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
#     }
#     principals {
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#       type        = "Federated"
#     }
#   }
# }

# resource "aws_iam_role" "alb_controller" {
#   assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
#   name               = format("%s-alb-controller", var.cluster_name)
# }

# data "aws_iam_policy_document" "aws_load_balancer_controller_policy" {
#   version = "2012-10-17"
#   statement {
#     effect = "Allow"
#     actions = [
#       "iam:CreateServiceLinkedRole",
#       "ec2:DescribeAccountAttributes",
#       "ec2:DescribeAddresses",
#       "ec2:DescribeAvailabilityZones",
#       "ec2:DescribeInternetGateways",
#       "ec2:DescribeVpcs",
#       "ec2:DescribeSubnets",
#       "ec2:DescribeSecurityGroups",
#       "ec2:DescribeInstances",
#       "ec2:DescribeNetworkInterfaces",
#       "ec2:DescribeTags",
#       "ec2:GetCoipPoolUsage",
#       "ec2:DescribeCoipPools",
#       "elasticloadbalancing:DescribeLoadBalancers",
#       "elasticloadbalancing:DescribeLoadBalancerAttributes",
#       "elasticloadbalancing:DescribeListeners",
#       "elasticloadbalancing:DescribeListenerCertificates",
#       "elasticloadbalancing:DescribeSSLPolicies",
#       "elasticloadbalancing:DescribeRules",
#       "elasticloadbalancing:DescribeTargetGroups",
#       "elasticloadbalancing:DescribeTargetGroupAttributes",
#       "elasticloadbalancing:DescribeTargetHealth",
#       "elasticloadbalancing:DescribeTags",
#       "elasticloadbalancing:SetWebAcl",
#       "elasticloadbalancing:ModifyListener",
#       "elasticloadbalancing:AddListenerCertificates",
#       "elasticloadbalancing:RemoveListenerCertificates",
#       "elasticloadbalancing:ModifyRule"
#     ]
#     resources = [
#       "*"
#     ]
#   }
#   statement {
#     effect = "Allow"
#     actions = [
#       "elasticloadbalancing:RegisterTargets",
#       "elasticloadbalancing:DeregisterTargets"
#     ]
#     resources = [
#       "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
#     ]
#   }
#   statement {
#     effect = "Allow"
#     actions = [
#       "elasticloadbalancing:AddTags",
#       "elasticloadbalancing:RemoveTags"
#     ]
#     resources = [
#       "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
#       "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
#       "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
#       "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
#     ]
#   }
# }

# resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
#   name        = format("%s-alb-controller-policy", var.cluster_name)
#   path        = "/"
#   description = var.cluster_name
#   policy = data.aws_iam_policy_document.aws_load_balancer_controller_policy.json
# }

# resource "aws_iam_policy_attachment" "aws_load_balancer_controller_policy" {
#   name = "aws_load_balancer_controller_policy"
#   roles = [aws_iam_role.alb_controller.name]
#   policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
# }

############################
# EKS ALB INGRESS CONTROLLER
############################

resource "helm_release" "alb_ingress_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account,
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    kubernetes_config_map.aws-auth
  ]

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  # set {
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   value = aws_iam_role.alb_controller.arn
  # }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = local.itm_vpc_id
  }
  set {
     name  = "image.repository"
     value = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"
  }
}