package installer

import (
	"fmt"
	"io"
	"net/http"
	"os"
)

const (
	baseURL      = "https://pkg.contrastsecurity.com/go-agent-release"
	artifactPath = "/%s/%s-%s/contrast-go"
)

// Install attempts to download a release of contrast-go matching version, os,
// and arch into path and chmod it to an executable.
func Install(version, os, arch, path string) error {
	return install(baseURL, version, os, arch, path)
}

func install(baseURL, version, goos, goarch, dst string) error {
	tmp, err := os.CreateTemp("", "contrast-go*")
	if err != nil {
		return fmt.Errorf("unable to create tmp for download: %w", err)
	}
	defer tmp.Close()

	url := fmt.Sprintf(baseURL+artifactPath, version, goos, goarch)

	res, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("unexpected connection issue: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode == http.StatusNotFound {
		// TODO(GO-1423): we could send 1-2 more HEAD requests for
		// path.Base(url) to figure out which part when wrong: was it os/arch?
		// version?
		return fmt.Errorf(
			"no '%v' release found for %v/%v at %v: %v",
			version, goos, goarch, baseURL, res.Status,
		)
	}
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf(
			"server did not return 200 for %v: %v",
			url, res.Status,
		)
	}

	if n, err := io.Copy(tmp, res.Body); err != nil {
		return fmt.Errorf(
			"couldn't download file (%d bytes read of %d expected): %w",
			n, res.ContentLength, err,
		)
	}

	fi, err := os.Stat(tmp.Name())
	if err != nil {
		return fmt.Errorf("cannot verify download: %w", err)
	}
	if res.ContentLength > -1 && fi.Size() != res.ContentLength {
		return fmt.Errorf(
			"downloaded file size %v does not match expected value %d",
			fi.Size(),
			res.ContentLength,
		)
	}

	if err := os.Rename(tmp.Name(), dst); err != nil {
		return err
	}

	if err := os.Chmod(dst, 0755); err != nil {
		return fmt.Errorf("permission issue: %w", err)
	}

	return nil
}
