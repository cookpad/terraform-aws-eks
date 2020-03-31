## template: jinja
#cloud-config
fqdn: eks-node-${cluster_name}-{{ v1.instance_id }}
bootcmd:
  - while [ ! -b $(readlink -f ${docker_volume_device}) ]; do echo "waiting for device ${docker_volume_device}"; sleep 1 ; done
  - blkid $(readlink -f ${docker_volume_device}) || mkfs -t ext4 $(readlink -f ${docker_volume_device})
  - e2label $(readlink -f ${docker_volume_device}) docker-volume
mounts:
- [/dev/disk/by-label/docker-volume, /var/lib/docker, ext4, "defaults,nofail,x-systemd.requires=cloud-init.service", 0, 0]
runcmd:
- [aws, --region={{ v1.region }}, ec2, create-tags, --resources={{ v1.instance_id }}, "--tags=Key=Name,Value=eks-node-${cluster_name}-{{ v1.instance_id }}"]
- [systemctl, restart, docker]
- [/etc/eks/bootstrap.sh, ${cluster_name}, --kubelet-extra-args, '--node-labels=${labels} --register-with-taints="${taints}"']
