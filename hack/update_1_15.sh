#!/bin/bash

set -xeuo pipefail

terraform state mv module.$1.aws_security_group.control_plane{,[0]}
terraform state mv module.$1.aws_security_group.node{,[0]}
terraform state mv module.$1.aws_security_group_rule.node_ingress_self{,[0]}
terraform state rm module.$1.aws_security_group_rule.node_ingress_cluster
