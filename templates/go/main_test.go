package main

import "testing"

func TestGreet(t *testing.T) {
	want := "Hello from my-app!"
	if got := greet(); got != want {
		t.Errorf("greet() = %q, want %q", got, want)
	}
}
