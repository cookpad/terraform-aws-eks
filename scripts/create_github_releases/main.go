package main

import (
	"fmt"
	"log"
	"net/url"
	"os"
	"regexp"
	"strings"

	"github.com/pkg/browser"
	"github.com/pkg/errors"
)

var (
	// tag must specify major.minor.patch or major.minor.patch-rc#
	// (e.g. 1.12.1, 1.12.1-rc1)
	validTag = regexp.MustCompile(`^\d+\.\d+\.\d+(-rc\d+)?$`)
	// target must specify release branch for releasing
	// or main for release candidates
	validTarget = regexp.MustCompile(`^(release-\d+-\d+|main)$`)
	// true or false
	validPrerelease = regexp.MustCompile(`^(true|false)$`)
	// yes or no
	validYesNo = regexp.MustCompile(`^(yes|no)$`)
)

func scanInputFromStdio(policy *regexp.Regexp, format *string, question, errMsg string) error {
	fmt.Println(question)
	fmt.Print("> ")
	fmt.Scanf("%s", format)

	// validate policy
	if !policy.Match([]byte(*format)) {
		return errors.New(errMsg)
	}
	return nil
}

// validateRelease validates policies for releases
// used for release candidates. Return target branch name
// based on the specified tag name.
func validateRelease(tag, preRelease string) (string, error) {
	if strings.Contains(tag, "-rc") {
		// release candidates must be released as prereleases
		if preRelease == "false" {
			return "", errors.New("[ERROR] Prerelease must be true for release candidates")
		}
		// release candidates must use main branch as a target
		return "main", nil
	} else {
		versions := strings.Split(tag, ".")
		// naming convention for release branch is release-{major}-{minor}
		return fmt.Sprintf("release-%s-%s", versions[0], versions[1]), nil
	}
}

func main() {
	fmt.Println("Start creating new GitHub Release interactively!")

	var tag, target, preRelease, confirm string

	if err := scanInputFromStdio(
		validTag,
		&tag,
		"Q. Input version tag with the format {major}.{minor}.{patch} or {major}.{minor}.{patch}-{rc#} (e.g. 1.19.0 or 1.19.0-rc1)",
		"[ERROR] Version tag must follow the format {major}.{minor}.{patch} or {major}.{minor}.{patch}-{rc#}",
	); err != nil {
		log.Fatalln(err.Error())
	}

	if err := scanInputFromStdio(
		validPrerelease,
		&preRelease,
		"Q. Is prerelease? (Set true for release candidates) (e.g. true or false)",
		"[ERROR] Prerelease must be true or false",
	); err != nil {
		log.Fatalln(err.Error())
	}

	target, err := validateRelease(tag, preRelease)
	if err != nil {
		log.Fatal(err.Error())
	}

	title := fmt.Sprintf("Release %s", tag)

	repositoryURL := "https://github.com/cookpad/terraform-aws-eks"

	// Check inputs
	fmt.Println("# Check input to be used for a GitHub Release")
	fmt.Println("tag:", tag)
	fmt.Println("target branch:", target)
	fmt.Println("pre release:", preRelease)
	fmt.Println("title:", title)
	fmt.Println()

	if err := scanInputFromStdio(
		validYesNo,
		&confirm,
		"Are these inputs correct? (yes or no)",
		"[ERROR] Invalid confirmation",
	); err != nil {
		log.Fatalln(err.Error())
	}
	if confirm != "yes" {
		fmt.Println("Canceled interactive GitHub release creation.")
		os.Exit(0)
	}

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
