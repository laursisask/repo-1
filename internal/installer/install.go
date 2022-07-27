// Copyright 2022 Contrast Security, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package installer

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

const (
	artifactPath = "/%s/%s-%s/contrast-go"

	agentArchivePg = `For a full list of versions, see
	https://docs.contrastsecurity.com/en/go-agent-release-notes-and-archive.html`

	badver            = `Version %q does not exist. ` + agentArchivePg
	sysRequirementsPg = `For system requirements, see
	https://docs.contrastsecurity.com/en/go-system-requirements.html`

	agentInstallPg = "https://docs.contrastsecurity.com/en/install-go.html"
	unknownError   = `Sorry, something strange happened. Please try again later or
install manually. For the latter, see the instructions at
` + agentInstallPg
)

// Install attempts to download a release of contrast-go matching version, os,
// and arch into path and chmod it to an executable.
func Install(baseURL, version, os, arch, path string) error {
	id := installData{
		baseURL: baseURL,
		version: version,
		os:      os,
		arch:    arch,
		dst:     path,
	}
	tmp, err := id.download()
	if err != nil {
		return err
	}
	return id.install(tmp)
}

type installData struct {
	baseURL string
	version string // version to download
	os      string // target os
	arch    string // target arch
	dst     string // final destination

	tmpdir string // set during testing to facilitate cleanup, otherwise empty
}

// download to a temp location, returning the temp file's location
func (id *installData) download() (string, error) {
	url := fmt.Sprintf(id.baseURL+artifactPath, id.version, id.os, id.arch)
	tmp, err := os.CreateTemp(id.tmpdir, "contrast-go*")
	if err != nil {
		return "", fmt.Errorf("unable to create tmp for download: %w", err)
	}
	defer tmp.Close()

	res, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("unexpected connection issue: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode == http.StatusNotFound {
		return "", id.dlNotFoundError(res)
	}
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf(
			"server did not return 200 for %v: %v",
			url, res.Status,
		)
	}

	if n, err := io.Copy(tmp, res.Body); err != nil {
		return "", fmt.Errorf(
			"couldn't download file (%d bytes read of %d expected): %w",
			n, res.ContentLength, err,
		)
	}

	fi, err := os.Stat(tmp.Name())
	if err != nil {
		return "", fmt.Errorf("cannot verify download: %w", err)
	}
	if res.ContentLength > -1 && fi.Size() != res.ContentLength {
		return "", fmt.Errorf(
			"downloaded file size %v does not match expected value %d",
			fi.Size(),
			res.ContentLength,
		)
	}
	return tmp.Name(), nil
}

// move from temp location to final
func (id installData) install(tmpFile string) error {
	if err := os.Rename(tmpFile, id.dst); err != nil {
		return err
	}

	if err := os.Chmod(id.dst, 0755); err != nil {
		return fmt.Errorf("permission issue: %w", err)
	}

	return nil
}

// determine what went wrong and return a nice error for the user
func (id installData) dlNotFoundError(res *http.Response) error {
	// first, check the version
	url := fmt.Sprintf("%s/%s", id.baseURL, id.version)
	res2, err := http.Get(url)
	if err != nil {
		return fmt.Errorf(badver, id.version)
	}
	defer res2.Body.Close()
	if res2.StatusCode != http.StatusOK {
		// invalid version; tell user what versions are valid
		res2, err = http.Get(id.baseURL)
		if err != nil {
			return fmt.Errorf(badver, id.version)
		}
		defer res2.Body.Close()
		if res2.StatusCode != http.StatusOK {
			return fmt.Errorf(badver, id.version)
		}
		avail, err := listVersions(res2.Body)
		if err != nil {
			return fmt.Errorf(badver, id.version)
		}

		return &errBadVersion{
			availableVersions: avail,
			badVersion:        id.version,
		}
	}

	avail, err := listPlatforms(res2.Body)
	if err != nil || len(avail) < 2 {
		return fmt.Errorf(unknownError)
	}
	// os and/or arch is invalid
	return &errBadPlat{
		available: avail,
		arch:      id.arch,
		os:        id.os,
	}
}

// reads html from body, returning extracted platforms
func listPlatforms(body io.Reader) ([]string, error) {
	var plats []string
	subdirs, err := htmlDir(body)
	if err != nil {
		return nil, err
	}
	for _, sub := range subdirs {
		if !strings.Contains(sub, "-") {
			// all platforms contain a dash: os-arch. throw away anything else.
			continue
		}
		plats = append(plats, sub)
	}
	return plats, nil
}

type errBadPlat struct {
	available []string
	arch, os  string
}

func (err *errBadPlat) Error() string {
	return fmt.Sprintf("contrast-go is not available for platform \"%s-%s\". Available platforms:\n\t%s\n%s",
		err.os, err.arch, strings.Join(err.available, ", "), sysRequirementsPg)
}
