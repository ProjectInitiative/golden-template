package main

import (
	"testing"
)

func TestVersion(t *testing.T) {
	if Version == "" {
		t.Error("expected Version to be set via ldflags")
	}
}
