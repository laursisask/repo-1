package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"github.com/contrast-security-inc/contrast-go-installer/internal/installer"
)

func usage() {
	cmd := filepath.Base(os.Args[0])
	out := flag.CommandLine.Output()

	fmt.Fprintf(out, "usage: %s <version>\n", cmd)

	fmt.Fprintf(out, "\nexamples:\n")
	fmt.Fprintf(out, "\t%s latest\n", cmd)
	fmt.Fprintf(out, "\t%s 2.8.0\n", cmd)

	fmt.Fprintf(out, "\nfor a full list of available versions, please visit:\n")
	fmt.Fprintf(out, "\thttps://docs.contrastsecurity.com/en/go-agent-release-notes-and-archive.html\n\n")
}

func main() {
	flag.Usage = usage

	flag.Parse()
	if len(flag.Args()) != 1 {
		flag.Usage()
		os.Exit(2)
	}

	version := flag.Args()[0]
	path := filepath.Join(os.Getenv("GOBIN"), "contrast-go")

	if err := installer.Install(version, runtime.GOOS, runtime.GOARCH, path); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	fmt.Printf(
		"Release for %s/%s @ %s installed to %s.\n",
		runtime.GOOS, runtime.GOARCH, version, path,
	)
}
