package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

const githubReposFixture = `
case "$*" in
  "org list --limit 100") printf '%s\n' First empty ;;
  "api --paginate orgs/First/repos?per_page=100 "*) printf '%s\n' First/zed First/api ;;
  "api --paginate orgs/empty/repos?per_page=100 "*) ;;
  *) printf 'unexpected arguments: %s\n' "$*" >&2; exit 1 ;;
esac
`

func TestGenerateGitHubReposWritesAFilePerOrganization(t *testing.T) {
	fakeGH(t, githubReposFixture)
	dir := t.TempDir()
	stale := filepath.Join(dir, "github-repos-left.json")
	if err := os.WriteFile(stale, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := generateGitHubRepos(dir); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "github-repos-first.json"))
	if err != nil {
		t.Fatal(err)
	}
	var got snippetGroup
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	want := snippetGroup{
		Name:     "GitHub - Repo - First",
		Snippets: []snippet{{Desc: "api", Text: "First/api"}, {Desc: "zed", Text: "First/zed"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("github-repos-first.json = %v, want %v", got, want)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Errorf("files = %v, want only github-repos-first.json", entries)
	}
}

func TestGenerateGitHubReposKeepsExistingFilesOnFailure(t *testing.T) {
	fakeGH(t, `
case "$*" in
  "org list --limit 100") printf 'first\n' ;;
  *) printf 'permission denied\n' >&2; exit 1 ;;
esac
`)
	dir := t.TempDir()
	existing := filepath.Join(dir, "github-repos-first.json")
	if err := os.WriteFile(existing, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := generateGitHubRepos(dir); err == nil || !strings.Contains(err.Error(), "first") {
		t.Fatalf("generateGitHubRepos() error = %v, want the failing organization", err)
	}
	if data, _ := os.ReadFile(existing); string(data) != "{}" {
		t.Error("github-repos-first.json was overwritten on failure")
	}
}
