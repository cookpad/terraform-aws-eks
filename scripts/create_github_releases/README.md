# Create new Github Releases

This tiny script enforces the current [release policy](../../RELEASING.md) to create a new GitHub release.

## Usage

```
go run main.go
```

## Example

```
$ go run main.go
Start creating new GitHub Release interactively!

1. Input version tag with the format {major}.{minor}.{patch} or {major}.{minor}.{patch}-{rc#} (e.g. 1.19.0 or 1.19.0-rc10)
> 1.19.1
2. Input target with the format release-{major}-{minor} (e.g. release-1-19)
> release-1-19
3. Is prerelease? (Set true for release candidates) (e.g. true or false)
> true
Input for GitHub Releases are successfully passed.
Please click 'Auto-generate release notes' button on your GitHub Release page and check the generated contents before you publish this release.
```
