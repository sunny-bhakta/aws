### Lif policy
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::831975835566:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:sunny-bhakta@77013204/aws@1361501698:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### Bootstsp Manual role

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "BackendStateS3",
			"Effect": "Allow",
			"Action": [
				"s3:ListBucket"
			],
			"Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566",
			"Condition": {
				"StringLike": {
					"s3:prefix": [
						"aws/devops-nestjs/*"
					]
				}
			}
		},
		{
			"Sid": "BackendStateS3Object",
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject",
				"s3:DeleteObject"
			],
			"Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566/aws/devops-nestjs/*"
		},
		{
			"Sid": "ReadIdentity",
			"Effect": "Allow",
			"Action": [
				"sts:GetCallerIdentity"
			],
			"Resource": "*"
		},
		{
			"Sid": "Ec2VpcAndNetworking",
			"Effect": "Allow",
			"Action": [
				"ec2:DescribeVpcs",
				"ec2:DescribeVpcAttribute",
				"ec2:DescribeSubnets",
				"ec2:DescribeRouteTables",
				"ec2:DescribeInternetGateways",
				"ec2:DescribeSecurityGroups",
				"ec2:DescribeAvailabilityZones",
				"ec2:DescribeAccountAttributes",
				"ec2:CreateSecurityGroup",
				"ec2:DeleteSecurityGroup",
				"ec2:AuthorizeSecurityGroupIngress",
				"ec2:RevokeSecurityGroupIngress",
				"ec2:AuthorizeSecurityGroupEgress",
				"ec2:RevokeSecurityGroupEgress",
				"ec2:CreateTags",
				"ec2:DeleteTags"
			],
			"Resource": "*"
		},
		{
			"Sid": "AlbAndTargetGroup",
			"Effect": "Allow",
			"Action": [
				"elasticloadbalancing:Describe*",
				"elasticloadbalancing:CreateLoadBalancer",
				"elasticloadbalancing:ModifyLoadBalancerAttributes",
				"elasticloadbalancing:DeleteLoadBalancer",
				"elasticloadbalancing:CreateTargetGroup",
				"elasticloadbalancing:DeleteTargetGroup",
				"elasticloadbalancing:CreateListener",
				"elasticloadbalancing:DeleteListener",
				"elasticloadbalancing:ModifyListener",
				"elasticloadbalancing:ModifyTargetGroup",
				"elasticloadbalancing:AddTags",
				"elasticloadbalancing:RemoveTags",
				"elasticloadbalancing:ModifyTargetGroupAttributes"
			],
			"Resource": "*"
		},
		{
			"Sid": "EcsAndTaskDefinitions",
			"Effect": "Allow",
			"Action": [
				"ecs:Describe*",
				"ecs:List*",
				"ecs:CreateCluster",
				"ecs:DeleteCluster",
				"ecs:RegisterTaskDefinition",
				"ecs:DeregisterTaskDefinition",
				"ecs:CreateService",
				"ecs:UpdateService",
				"ecs:DeleteService",
				"ecs:TagResource",
				"ecs:UntagResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "EcrRepoManagement",
			"Effect": "Allow",
			"Action": [
				"ecr:DescribeRepositories",
				"ecr:CreateRepository",
				"ecr:DeleteRepository",
				"ecr:PutImageScanningConfiguration",
				"ecr:PutImageTagMutability",
				"ecr:TagResource",
				"ecr:UntagResource",
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:BatchGetImage",
				"ecr:CompleteLayerUpload",
				"ecr:GetDownloadUrlForLayer",
				"ecr:InitiateLayerUpload",
				"ecr:PutImage",
				"ecr:UploadLayerPart",
				"ecr:ListTagsForResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "CloudWatchLogs",
			"Effect": "Allow",
			"Action": [
				"logs:DescribeLogGroups",
				"logs:CreateLogGroup",
				"logs:DeleteLogGroup",
				"logs:PutRetentionPolicy",
				"logs:TagResource",
				"logs:UntagResource",
				"logs:ListTagsForResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "IamForTerraformManagedRoles",
			"Effect": "Allow",
			"Action": [
				"iam:GetRole",
				"iam:CreateRole",
				"iam:DeleteRole",
				"iam:UpdateAssumeRolePolicy",
				"iam:AttachRolePolicy",
				"iam:DetachRolePolicy",
				"iam:PutRolePolicy",
				"iam:DeleteRolePolicy",
				"iam:GetRolePolicy",
				"iam:ListAttachedRolePolicies",
				"iam:ListRolePolicies",
				"iam:TagRole",
				"iam:UntagRole",
				"iam:PassRole"
			],
			"Resource": [
				"arn:aws:iam::831975835566:role/devops-nestjs-*",
				"arn:aws:iam::831975835566:role/github-actions-ecr-push",
				"arn:aws:iam::831975835566:role/ecsTaskExecutionRole"
			]
		},
		{
			"Sid": "RdsOptional",
			"Effect": "Allow",
			"Action": [
				"rds:Describe*",
				"rds:CreateDBInstance",
				"rds:DeleteDBInstance",
				"rds:ModifyDBInstance",
				"rds:CreateDBSubnetGroup",
				"rds:DeleteDBSubnetGroup",
				"rds:AddTagsToResource",
				"rds:RemoveTagsFromResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "SecretsManagerOptional",
			"Effect": "Allow",
			"Action": [
				"secretsmanager:CreateSecret",
				"secretsmanager:DeleteSecret",
				"secretsmanager:DescribeSecret",
				"secretsmanager:PutSecretValue",
				"secretsmanager:TagResource",
				"secretsmanager:UntagResource"
			],
			"Resource": "*"
		}
	]
}
```
### Easy
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackendStateS3Bucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["aws/devops-nestjs/*"]
        }
      }
    },
    {
      "Sid": "BackendStateS3Objects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566/aws/devops-nestjs/*"
    },
    {
      "Sid": "CoreInfraBootstrap",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "ecs:*",
        "ecr:*",
        "logs:*",
        "rds:*",
        "secretsmanager:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamManagementNoPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassRoleRestrictedToEcsTaskRoles",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": [
        "arn:aws:iam::831975835566:role/devops-nestjs-ecs-task-execution-role",
        "arn:aws:iam::831975835566:role/devops-nestjs-ecs-task-role",
        "arn:aws:iam::831975835566:role/ecsTaskExecutionRole"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```

### RDS Lock

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackendStateS3Bucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "aws/devops-nestjs/*"
          ]
        }
      }
    },
    {
      "Sid": "BackendStateS3Objects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::devops-nestjs-tf-state-831975835566/aws/devops-nestjs/*"
    },
    {
      "Sid": "BackendStateDynamoLockingOptional",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-south-1:831975835566:table/terraform-locks"
    },
    {
      "Sid": "CoreInfraBootstrapBroad",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "ecs:*",
        "ecr:*",
        "logs:*",
        "rds:*",
        "secretsmanager:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamManagementWithoutPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassRoleRestrictedToEcsTasks",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::831975835566:role/devops-nestjs-ecs-task-execution-role",
        "arn:aws:iam::831975835566:role/devops-nestjs-ecs-task-role",
        "arn:aws:iam::831975835566:role/ecsTaskExecutionRole"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```