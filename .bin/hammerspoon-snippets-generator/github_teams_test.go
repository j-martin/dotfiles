package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

const githubTeamsFixture = `
case "$*" in
  "org list --limit 100") printf '%s\n' First empty ;;
  "api --paginate orgs/First/teams?per_page=100 "*) printf 'platform\tPlatform Team\napi\tAPI\n' ;;
  "api --paginate orgs/empty/teams?per_page=100 "*) ;;
  *) printf 'unexpected arguments: %s\n' "$*" >&2; exit 1 ;;
esac
`

func TestGenerateGitHubTeamsWritesAFilePerOrganization(t *testing.T) {
	fakeGH(t, githubTeamsFixture)
	dir := t.TempDir()
	stale := filepath.Join(dir, "github-teams-left.json")
	if err := os.WriteFile(stale, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := generateGitHubTeams(dir); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(dir, "github-teams-first.json"))
	if err != nil {
		t.Fatal(err)
	}
	var got snippetGroup
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	want := snippetGroup{
		Name: "GitHub - Team - First",
		Snippets: []snippet{
			{Desc: "API", Text: "@First/api"},
			{Desc: "Platform Team", Text: "@First/platform"},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("github-teams-first.json = %v, want %v", got, want)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Errorf("files = %v, want only github-teams-first.json", entries)
	}
}

func TestGenerateGitHubTeamsKeepsExistingFilesOnFailure(t *testing.T) {
	fakeGH(t, `
case "$*" in
  "org list --limit 100") printf 'first\n' ;;
  *) printf 'permission denied\n' >&2; exit 1 ;;
esac
`)
	dir := t.TempDir()
	existing := filepath.Join(dir, "github-teams-first.json")
	if err := os.WriteFile(existing, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := generateGitHubTeams(dir); err == nil || !strings.Contains(err.Error(), "first") {
		t.Fatalf("generateGitHubTeams() error = %v, want the failing organization", err)
	}
	if data, _ := os.ReadFile(existing); string(data) != "{}" {
		t.Error("github-teams-first.json was overwritten on failure")
	}
}
