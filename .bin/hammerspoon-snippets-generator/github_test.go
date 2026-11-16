package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func fakeGH(t *testing.T, script string) {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("PATH", dir)
	if err := os.WriteFile(filepath.Join(dir, "gh"), []byte("#!/bin/sh\nset -eu\n"+script), 0o755); err != nil {
		t.Fatal(err)
	}
}

func TestListGitHubOrgs(t *testing.T) {
	fakeGH(t, `
test "$*" = "org list --limit 100"
printf 'first\r\nsecond\n'
`)
	got, err := listGitHubOrgs()
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"first", "second"}; !reflect.DeepEqual(got, want) {
		t.Errorf("listGitHubOrgs() = %v, want %v", got, want)
	}
}

func TestListGitHubOrgsExpandsFullLists(t *testing.T) {
	want := make([]string, 101)
	for i := range want {
		want[i] = fmt.Sprintf("org-%03d", i)
	}
	t.Setenv("GH_TEST_FIRST_PAGE", strings.Join(want[:100], "\n"))
	t.Setenv("GH_TEST_ALL", strings.Join(want, "\n"))
	fakeGH(t, `
case "$*" in
  "org list --limit 100") printf '%s\n' "$GH_TEST_FIRST_PAGE" ;;
  "org list --limit 200") printf '%s\n' "$GH_TEST_ALL" ;;
  *) printf 'unexpected arguments: %s\n' "$*" >&2; exit 1 ;;
esac
`)
	got, err := listGitHubOrgs()
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("listGitHubOrgs() = %v, want %v", got, want)
	}
}

func TestNameFromEmail(t *testing.T) {
	tests := map[string]string{
		"jane.doe@example.com":           "Jane Doe",
		"Jean-Martin.Archer@example.com": "Jean-Martin Archer",
		"anne.marie.smith@example.com":   "Anne Marie Smith",
		"jdoe@example.com":               "",
		"jane.doe2@example.com":          "",
		"jane.doe":                       "",
		"":                               "",
	}
	for email, want := range tests {
		if got := nameFromEmail(email); got != want {
			t.Errorf("nameFromEmail(%q) = %q, want %q", email, got, want)
		}
	}
}

func TestCoworkers(t *testing.T) {
	got := coworkers(
		[]member{
			{Login: "zed", Name: "Zed GitHub"},
			{Login: "nobody", Name: ""},
			{Login: "adoe", Name: "Alice Profile"},
		},
		[]samlIdentity{
			{Login: "zed", Email: "zed.smith@example.com"},
			{Login: "adoe", Email: "adoe@example.com"},
		},
	)
	want := []coworker{
		{Login: "zed", Email: "zed.smith@example.com", Name: "Zed Smith"},
		{Login: "nobody", Email: "", Name: "nobody"},
		{Login: "adoe", Email: "adoe@example.com", Name: "Alice Profile"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("coworkers() = %v, want %v", got, want)
	}
}

func TestCoworkerGroupSortsByDescription(t *testing.T) {
	all := []coworker{{Login: "zed", Name: "Zed Smith"}, {Login: "adoe", Name: "alice Doe"}}
	got := coworkerGroup("GitHub - Coworkers", all, func(c coworker) string { return c.Login })
	want := snippetGroup{
		Name:     "GitHub - Coworkers",
		Snippets: []snippet{{Desc: "alice Doe", Text: "adoe"}, {Desc: "Zed Smith", Text: "zed"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("coworkerGroup() = %v, want %v", got, want)
	}
}

func TestCoworkerGroupSkipsEmptyText(t *testing.T) {
	all := []coworker{{Login: "zed", Email: "zed.smith@example.com", Name: "Zed Smith"}, {Login: "bot", Name: "bot"}}
	got := coworkerGroup("Email", all, func(c coworker) string { return c.Email })
	want := []snippet{{Desc: "Zed Smith", Text: "zed.smith@example.com"}}
	if !reflect.DeepEqual(got.Snippets, want) {
		t.Errorf("coworkerGroup().Snippets = %v, want %v", got.Snippets, want)
	}
}

func TestCoworkerGroupDeduplicatesTexts(t *testing.T) {
	all := []coworker{
		{Login: "jane", Email: "jane.doe@first.test", Name: "Jane Doe"},
		{Login: "jane", Email: "jane.doe@first.test", Name: "Jane Doe"},
		{Login: "jane", Email: "jane.doe@second.test", Name: "Jane Doe"},
	}
	logins := coworkerGroup("GitHub - Coworkers", all, func(c coworker) string { return c.Login })
	if want := []snippet{{Desc: "Jane Doe", Text: "jane"}}; !reflect.DeepEqual(logins.Snippets, want) {
		t.Errorf("logins = %v, want %v", logins.Snippets, want)
	}
	emails := coworkerGroup("Email", all, func(c coworker) string { return c.Email })
	want := []snippet{{Desc: "Jane Doe", Text: "jane.doe@first.test"}, {Desc: "Jane Doe", Text: "jane.doe@second.test"}}
	if !reflect.DeepEqual(emails.Snippets, want) {
		t.Errorf("emails = %v, want %v", emails.Snippets, want)
	}
}

const githubFixture = `
case "$1 $2" in
  "org list") printf '%s\n' first second; exit 0 ;;
  "api graphql") ;;
  *) printf 'unexpected command: %s\n' "$*" >&2; exit 1 ;;
esac
org=
kind=
for arg do
  case "$arg" in
    org=*) org="${arg#org=}" ;;
    *membersWithRole*) kind=members ;;
    *samlIdentityProvider*) kind=identities ;;
  esac
done
if [ "$org" = "${GH_TEST_FAIL_ORG:-}" ]; then
  printf 'permission denied\n' >&2
  exit 1
fi
case "$org:$kind" in
  first:members)
    printf '%s\n' '{"login":"alice","name":"Alice Profile"}' '{"login":"shared","name":"Sam Profile"}' ;;
  first:identities)
    printf '%s\n' '{"login":"alice","email":"alice.smith@first.test"}' '{"login":"shared","email":"sam.shared@first.test"}' ;;
  second:members)
    printf '%s\n' '{"login":"bob","name":"Bob Profile"}' '{"login":"shared","name":"Sam Profile"}' ;;
  second:identities)
    printf '%s\n' '{"login":"bob","email":"bob.jones@second.test"}' '{"login":"shared","email":"sam.shared@second.test"}' ;;
  *) printf 'unexpected query: %s\n' "$*" >&2; exit 1 ;;
esac
`

func TestGenerateGitHubWritesFilesPerOrganization(t *testing.T) {
	fakeGH(t, githubFixture)
	dir := t.TempDir()
	for _, stale := range []string{"coworkers-github.json", "coworkers-email.json", "coworkers-github-left.json"} {
		if err := os.WriteFile(filepath.Join(dir, stale), []byte("{}"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := generateGitHub(dir); err != nil {
		t.Fatal(err)
	}
	want := map[string]snippetGroup{
		"coworkers-github-first.json": {
			Name:     "GitHub - Coworkers - first",
			Snippets: []snippet{{Desc: "Alice Smith", Text: "alice"}, {Desc: "Sam Shared", Text: "shared"}},
		},
		"coworkers-github-second.json": {
			Name:     "GitHub - Coworkers - second",
			Snippets: []snippet{{Desc: "Bob Jones", Text: "bob"}, {Desc: "Sam Shared", Text: "shared"}},
		},
		"coworkers-email-first.json": {
			Name: "Email - first",
			Snippets: []snippet{
				{Desc: "Alice Smith", Text: "alice.smith@first.test"},
				{Desc: "Sam Shared", Text: "sam.shared@first.test"},
			},
		},
		"coworkers-email-second.json": {
			Name: "Email - second",
			Snippets: []snippet{
				{Desc: "Bob Jones", Text: "bob.jones@second.test"},
				{Desc: "Sam Shared", Text: "sam.shared@second.test"},
			},
		},
	}
	for file, expected := range want {
		data, err := os.ReadFile(filepath.Join(dir, file))
		if err != nil {
			t.Fatal(err)
		}
		var got snippetGroup
		if err := json.Unmarshal(data, &got); err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(got, expected) {
			t.Errorf("%s = %v, want %v", file, got, expected)
		}
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != len(want) {
		t.Errorf("files = %v, want only %d per-organization files", entries, len(want))
	}
}

func TestGenerateGitHubSkipsUsersWithoutOrganizations(t *testing.T) {
	fakeGH(t, `test "$*" = "org list --limit 100"`)
	dir := t.TempDir()
	if err := generateGitHub(dir); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Errorf("files = %v, want none", entries)
	}
}

func TestGenerateGitHubKeepsExistingFilesOnFailure(t *testing.T) {
	tests := map[string]struct {
		script string
		org    string
		want   string
	}{
		"discovery": {
			script: "printf 'authentication required\\n' >&2; exit 1",
			want:   "listing GitHub organizations:",
		},
		"organization": {
			script: githubFixture,
			org:    "second",
			want:   "fetching second:",
		},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			fakeGH(t, tt.script)
			t.Setenv("GH_TEST_FAIL_ORG", tt.org)
			dir := t.TempDir()
			previous := `{"name":"Previous","snippets":[]}`
			for _, file := range []string{"coworkers-github-first.json", "coworkers-email-first.json"} {
				if err := os.WriteFile(filepath.Join(dir, file), []byte(previous), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			if err := generateGitHub(dir); err == nil || !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("generateGitHub() error = %v, want %q", err, tt.want)
			}
			for _, file := range []string{"coworkers-github-first.json", "coworkers-email-first.json"} {
				data, err := os.ReadFile(filepath.Join(dir, file))
				if err != nil {
					t.Fatal(err)
				}
				if string(data) != previous {
					t.Errorf("%s was overwritten on failure", file)
				}
			}
		})
	}
}
