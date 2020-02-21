## template: jinja
#cloud-config
fqdn: eks-node-${cluster_name}-{{ v1.instance_id }}
fs_setup:
# Create a filesystem on an attached EBS volume. Only one of them should succeed.
- device: /dev/nvme0n1
  filesystem: ext4
  label: docker-vol
  partition: none
- device: /dev/nvme1n1
  filesystem: ext4
  label: docker-vol
  partition: none
- device: /dev/xvdf
  filesystem: ext4
  label: docker-vol
  partition: none
mounts:
- [/dev/disk/by-label/docker-vol, /var/lib/docker, ext4, "defaults,noatime", 0, 0]
runcmd:
- [aws, --region={{ v1.region }}, ec2, create-tags, --resources={{ v1.instance_id }}, "--tags=Key=Name,Value=eks-node-${cluster_name}-{{ v1.instance_id }}"]
- [systemctl, restart, docker]
- [/etc/eks/bootstrap.sh, ${cluster_name}, --kubelet-extra-args, '--node-labels=${labels} --register-with-taints="${taints}"']
