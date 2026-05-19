package handler

import "testing"

func TestHandle(t *testing.T) {
	got := Handle("world")
	want := "Hello, world!"
	if got != want {
		t.Errorf("Handle() = %q, want %q", got, want)
	}
}
