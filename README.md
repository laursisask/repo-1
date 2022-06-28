This tool is a work in progress and the contents of this README are expected to
change.

# Temporary Requirements

These requirements will go away when we release the tool. For now, they are
intended to let us develop this privately.

1. Your `GOPRIVATE` environment variable must include
   `github.com/Contrast-Security-Inc/*`. To check if if does, run `go env
   GOPRIVATE`. To add it: `go env -w GOPRIVATE="$(go env
   GOPRIVATE),github.com/Contrast-Security-Inc/*"` 
2. Run `git config --add --global
   url."git@github.com:Contrast-Security-Inc/".insteadOf
   https://github.com/Contrast-Security-Inc/`. This will allow you to fetch
   private module over ssh.

# Usage

`go run github.com/contrast-security-inc/contrast-go-installer@latest`

# System Requirements

* [go](https://go.dev/dl/)
