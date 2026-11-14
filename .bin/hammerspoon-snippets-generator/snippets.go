package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type snippet struct {
	Desc string `json:"desc"`
	Text string `json:"text"`
}

// snippetGroup is a SnippetGroup of ~/.hammerspoon/snippets/matcher.lua, its name prefixed to every label in the picker.
type snippetGroup struct {
	Name     string    `json:"name"`
	Snippets []snippet `json:"snippets"`
}

// newGroup returns a group named name with snippets sorted by description, ignoring case.
func newGroup(name string, snippets []snippet) snippetGroup {
	sort.Slice(snippets, func(i, j int) bool {
		return strings.ToLower(snippets[i].Desc) < strings.ToLower(snippets[j].Desc)
	})
	return snippetGroup{Name: name, Snippets: snippets}
}

// run returns the stdout of a command, its stderr in the error when it fails.
func run(name string, args ...string) ([]byte, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.Command(name, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return stdout.Bytes(), nil
}

// write writes group to dir/file and prints the outcome.
func write(dir, file string, group snippetGroup) error {
	path := filepath.Join(dir, file)
	written, err := writeJSON(path, group)
	if err != nil {
		return err
	}
	if written {
		fmt.Printf("Wrote %d snippets to %s\n", len(group.Snippets), path)
	} else {
		fmt.Printf("%d snippets unchanged in %s\n", len(group.Snippets), path)
	}
	return nil
}

// writeJSON replaces path atomically so Hammerspoon never reads a partial file.
// It returns false without writing when the content is unchanged, since Hammerspoon reloads on every change.
func writeJSON(path string, value any) (bool, error) {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return false, err
	}
	data = append(data, '\n')
	if existing, err := os.ReadFile(path); err == nil && bytes.Equal(existing, data) {
		return false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".snippets-*.json")
	if err != nil {
		return false, err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return false, err
	}
	if err := tmp.Close(); err != nil {
		return false, err
	}
	return true, os.Rename(tmp.Name(), path)
}
