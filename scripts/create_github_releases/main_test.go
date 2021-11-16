package main

import (
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/pkg/errors"
)

type input struct {
	tag        string
	preRelease string
}

type expect struct {
	target string
	err    error
}

func TestMain_validateRelease(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		input  *input
		expect *expect
	}{
		"release branch 1.19.0": {
			input:  &input{tag: "1.19.0", preRelease: "true"},
			expect: &expect{target: "release-1-19", err: nil},
		},
		"release branch 1.19.0 with false prerelease flag": {
			input:  &input{tag: "1.19.0", preRelease: "false"},
			expect: &expect{target: "release-1-19", err: nil},
		},
		"release candidate 1": {
			input:  &input{tag: "1.19.0-rc1", preRelease: "true"},
			expect: &expect{target: "main", err: nil},
		},
		"release candidate 1 with false prerelease flag": {
			input:  &input{tag: "1.19.0-rc1", preRelease: "false"},
			expect: &expect{target: "", err: errors.New("[ERROR] Prerelease must be true for release candidates")},
		},
	}

	for name, test := range tests {
		t.Run(name, func(t *testing.T) {
			t.Parallel()

			actual, err := validateRelease(test.input.tag, test.input.preRelease)
			if test.expect.err == nil && err != nil {
				t.Fatalf("err=%#v\n", err)
			}

			if diff := cmp.Diff(test.expect.target, actual); diff != "" {
				t.Errorf("\n(-expect, +actual)%s\n", diff)
			}

		})
	}

}
