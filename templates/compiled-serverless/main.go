package main

import (
	"fmt"
	"os"

	"my-service/cmd/function"
	"my-service/pkg/server"
)

// Version is injected at build time via ldflags (see flake.nix).
// Inspired by Fission's build info pattern:
// https://github.com/fission/fission/blob/main/.goreleaser.yml
var Version = "dev"

func main() {
	if len(os.Args) < 2 {
		server.Run()
		return
	}
	switch os.Args[1] {
	case "function":
		function.Run()
	case "server":
		server.Run()
	default:
		fmt.Fprintf(os.Stderr, "Usage: %s [server|function]\n", os.Args[0])
		os.Exit(1)
	}
}
