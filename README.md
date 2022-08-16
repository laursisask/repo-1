# contrast-go-installer
A tool to install Contrast Security's [contrast-go](https://docs.contrastsecurity.com/en/go.html),
which instruments web apps for library usage and vulnerability reporting (IAST).

`contrast-go-installer` chooses the correct binary for your OS and architecture,
and downloads the latest version - or a specific version, if desired.

Click for a [demo of contrast-go](http://www.youtube.com/watch?v=ffBWozHhASw)


# System Requirements
> **Note**
> We are including `contrast-go` requirements, not just `contrast-go-installer`,
because you likely want to use it on the same machine you downloaded on.
* Go, which can be downloaded from https://go.dev/dl/.
  * `contrast-go-installer` requires go1.17 or later.
  * `contrast-go` requires one of the two latest Go releases, following the [Go release policy](https://go.dev/doc/devel/release#policy). For more information, please see the [release notes](https://docs.contrastsecurity.com/en/go-agent-release-notes-and-archive.html).

* `contrast-go` also has [OS and architecture requirements](https://docs.contrastsecurity.com/en/go-system-requirements.html).

# Usage
Once you have `go` installed, just run one of the following commands.
<!-- TODO verify oss url -->
Download latest `contrast-go` version: 
```sh
$ go run github.com/contrastsecurity/contrast-go-installer@latest latest
```
or download a specific `contrast-go` version: 
```sh
$ go run github.com/contrastsecurity/contrast-go-installer@latest 3.1.0
```

The install location will be `$GOBIN` if set, otherwise `$GOPATH/bin`. If this
directory is not in `$PATH`, `contrast-go-installer` will warn you.

To change the install location, override $GOBIN for the above command:
```sh
$GOBIN=/path/to/dir go run github.com/contrastsecurity/contrast-go-installer@latest 3.1.0
```
<!-- NOTE: blank lines are *required* around markdown blocks inside <details>, or it won't render as markdown -->

# Additional Help
We want the installation experience to be painless. If you experience issues, please contact us via our [support portal](https://support.contrastsecurity.com/hc/en-us)
