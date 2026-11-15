package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCommandAvailableUsesPATH(t *testing.T) {
	for _, name := range []string{"gh", "gcloud"} {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			t.Setenv("PATH", dir)
			if commandAvailable(name) {
				t.Fatal("commandAvailable() = true before the command is on PATH")
			}
			path := filepath.Join(dir, name)
			if err := os.WriteFile(path, []byte("#!/bin/sh\n"), 0o644); err != nil {
				t.Fatal(err)
			}
			if commandAvailable(name) {
				t.Fatal("commandAvailable() = true for a non-executable file")
			}
			if err := os.Chmod(path, 0o755); err != nil {
				t.Fatal(err)
			}
			if !commandAvailable(name) {
				t.Fatal("commandAvailable() = false after the command is added to PATH")
			}
		})
	}
}
