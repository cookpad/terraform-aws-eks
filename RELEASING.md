# Releasing

This file contains notes explaining release and versioning procedures.

# Versioning

This module is versioned with a 3 part version number:

The Major and Minor parts of the version number follow the Kubernetes Major
and Minor version numbers.

The patch version version tracks patch releases of this module (not Kubernetes),
EKS only allows users to specify Major and Minor K8s versions.

# Compatibility

Upgrading the patch version of this module should not:

* Cause major downtime
* Require any additional manual steps

The exception to this is where either of the above are required to fix a
security issue (in this case the release notes will document this).

Upgrading the Major or minor version of this module:

* Upgrades the Kubernetes version
* Will require multiple terraform apply steps
* May require additional manual steps
* May cause short downtime of some components (where unavoidable)

The release notes will document this.

Pre release versions may be tagged. There are no guarantees attached to these
as they are intended for testing purposes only. They may well cause downtime
or otherwise break a cluster.

# Branching

`main` is the main development branch for this module. Changes to the module
and updates should be merged here via pull request. `main` should be maintained
with the most up-to date working configuration.

Once a particular version is ready for pre-production testing a branch named 
`release-<major>-<minor>` is created to maintain stable releases for that version.

Pre-Release versions, and release versions (once we are satisfied) are tagged
from these branches.

We expect to cherry-pick or backport essential changes to release branches.

## Release Cadence and Support

AWS release a new minor version of EKS approximately once per quarter (see the [EKS Kubernetes release calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html#kubernetes-release-calendar)). We aim to release a new stable minor version of `terraform-aws-eks` within one month of the upstream EKS release.

We will continue to support the latest 3 minor EKS versions. Security fixes will be back-ported and released on as a new patch version. Other major bugs may be back-ported based on user demand.

# Release Procedure

We use GitHub's [automated release note](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) feature to generate release notes for this module. Please follow the steps below to enforce our release policies described in this page.

* Review the pull requests merged since the last release, and ensure all required labels have been applied.
* Run `cd scripts/create_github_releases && go run main.go` and follow instructions to open a new GitHub Release page.
* Check the version has been published at https://registry.terraform.io/modules/cookpad/eks/aws
