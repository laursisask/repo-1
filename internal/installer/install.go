package installer

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

const (
	artifactPath = "/%s/%s-%s/contrast-go"

	agentArchivePg = `For a full list of versions, see
	https://docs.contrastsecurity.com/en/go-agent-release-notes-and-archive.html`

	badver = `Version %q does not exist. ` + agentArchivePg
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
	res2.Body.Close()
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

	// TODO(GO-1423): is os/arch wrong? print a nice message if so
	// hint: use htmlDir() to get the supported os/arch's

	return fmt.Errorf(badver, id.version)
}
