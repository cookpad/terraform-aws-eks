package main

import (
	"fmt"
	"log"
	"net/url"
	"regexp"
	"strings"

	"github.com/pkg/browser"
)

var (
	// tag must specify major.minor.patch or major.minor.patch-rc#
	// (e.g. 1.12.1, 1.12.1-rc1)
	validTag = regexp.MustCompile(`^\d+\.\d+\.\d+(-rc\d+)?$`)
	// target must specify release branch
	validTarget = regexp.MustCompile(`^release-\d+-\d+$`)
	// true or false
	validPrerelease = regexp.MustCompile(`^(true|false)$`)
)

func main() {
	fmt.Println("Start creating new GitHub Release interactively!\n")

	var tag string
	fmt.Println("1. Input version tag with the format {major}.{minor}.{patch} or {major}.{minor}.{patch}-{rc#} (e.g. 1.19.0 or 1.19.0-rc10)")
	fmt.Print("> ")
	fmt.Scanf("%s", &tag)

	if !validTag.Match([]byte(tag)) {
		log.Fatal("[ERROR] Version tag must follow the format {major}.{minor}.{patch} or {major}.{minor}.{patch}-{rc#}")
	}

	var target string
	fmt.Println("2. Input target with the format release-{major}-{minor} (e.g. release-1-19)")
	fmt.Print("> ")
	fmt.Scanf("%s", &target)

	if !validTarget.Match([]byte(target)) {
		log.Fatal("[ERROR] Target must follow the format release-{major}-{minor}")
	}

	var preRelease string
	fmt.Println("3. Is prerelease? (Set true for release candidates) (e.g. true or false)")
	fmt.Print("> ")
	fmt.Scanf("%s", &preRelease)

	if !validPrerelease.Match([]byte(preRelease)) {
		log.Fatal("[ERROR] Prerelease must be true or false")
	}

	if strings.Contains(tag, "-rc") && preRelease == "false" {
		log.Fatal("[ERROR] Prerelease must be true for release candidates")
	}

	title := fmt.Sprintf("Release %s", tag)

	repositoryURL := "https://github.com/cookpad/terraform-aws-eks"

	// https://docs.github.com/en/repositories/releasing-projects-on-github/automation-for-release-forms-with-query-parameters
	url, err := url.Parse(
		fmt.Sprintf("%s/releases/new?tag=%s&target=%s&title=%s&prerelease=%s", repositoryURL, tag, target, title, preRelease),
	)
	if err != nil {
		log.Fatal(err)
	}

	if err := browser.OpenURL(url.String()); err != nil {
		log.Fatal(err)
	}

	fmt.Println("Input for GitHub Releases are successfully passed.")
	fmt.Println("Please click 'Auto-generate release notes' button on your GitHub Release page and check the generated contents before you publish this release.")
}
