# Self-managed CoreDNS

This document describes how to migrate from CoreDNS as an EKS addon to self-managed CoreDNS.

> :warning: It is recommended that new clusters use the EKS addon, even if you intend to immediately migrate to self-managed.

## Steps

1. Ensure that the `critical_addons_coredns_preserve` variable is configured to `true`. This is the default value, and ensures no downtime for DNS during the migration.
1. In a separate plan/apply, set the `critical_addons_coredns_enabled` variable to `false`. This will delete the EKS addon, without deleting the associated manifests in the cluster.
1. Start managing the CoreDNS manifests however you see fit.

> :memo: It may be useful to take a snapshot of the resources previously managed by the addon - you can do so like so:
> 
> ```shell
> kubectl api-resources --verbs=list -o name | xargs -n 1 kubectl get --ignore-not-found -A -l eks.amazonaws.com/component=coredns -o yaml > coredns.yaml
> ```
> 
> Note that this will output more resources than necessary to manage CoreDNS (e.g. Deployment _and_ ReplicaSets _and_ Pods), as well as status fields, so is useful as a reference but should not be copied directly into e.g. your kustomize.


## Why?

The EKS addon for CoreDNS does not support reconfiguration (for example increasing replicas), as most `.spec` fields are managed by EKS, and any custom modifications to the CoreDNS resources will be overwritten by the EKS addon. To enable fine grained control over CoreDNS resources, it is necessary to migrate from the EKS addon to a self-managed CoreDNS, and this will usually need to be a seamless transition.
