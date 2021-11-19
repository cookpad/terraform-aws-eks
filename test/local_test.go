package test

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"gopkg.in/yaml.v3"
)

type parsedCRD struct {
	APIVersion string   `yaml:"apiVersion"`
	Kind       string   `yaml:"kind"`
	Metadata   metadata `yaml:"metadata"`
}

type metadata struct {
	Annotations annotations `yaml:"annotations"`
	Name        string      `yaml:"name"`
}

type annotations struct {
	EksAmazonawsComRoleArn              string `yaml:"eks.amazonaws.com/role-arn"`
	EksAmazonawsComStsRegionalEndpoints string `yaml:"eks.amazonaws.com/sts-regional-endpoints"`
}

func TestServiceAccountsUseStsRegionalEndpoint(t *testing.T) {
	addonsPath := "../modules/cluster/addons/"
	addonFiles, err := os.ReadDir(addonsPath)
	if err != nil {
		t.Error(err)
	}
	for _, v := range addonFiles {
		fileName := v.Name()
		if filepath.Ext(fileName) == ".yaml" {
			serviceaccounts, err := readServiceAccounts(addonsPath + fileName)
			if err != nil {
				t.Fatalf("err=%#v\n", err)
			}
			for _, v := range serviceaccounts {
				if v.Metadata.Annotations.EksAmazonawsComRoleArn != "" {
					assert.Equal(t, v.Metadata.Annotations.EksAmazonawsComStsRegionalEndpoints, "true", fmt.Sprintf("%s should be true", v.Metadata.Annotations.EksAmazonawsComStsRegionalEndpoints))
				}
			}
		}
	}
}

func readServiceAccounts(filename string) ([]parsedCRD, error) {
	f, err := os.Open(filename)
	defer f.Close()
	if err != nil {
		return nil, err
	}
	d := yaml.NewDecoder(f)
	var crds []parsedCRD
	for {
		var crd parsedCRD
		err := d.Decode(&crd)
		if errors.Is(err, io.EOF) {
			break
		}
		if crd == (parsedCRD{}) {
			continue
		}
		if crd.Kind == "ServiceAccount" {
			crds = append(crds, crd)
		}
	}
	return crds, nil
}
