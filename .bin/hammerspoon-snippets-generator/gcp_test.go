package main

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func project(id, name, parentType, parentID string) gcpProject {
	p := gcpProject{ProjectID: id, Name: name}
	p.Parent.Type = parentType
	p.Parent.ID = parentID
	return p
}

func TestFolderOrgsResolvesEachFolderOnce(t *testing.T) {
	projects := []gcpProject{
		project("a", "", "folder", "2"),
		project("b", "", "folder", "2"),
		project("c", "", "folder", "3"),
		project("d", "", "organization", "1"),
	}
	calls := map[string]int{}
	orgOf := map[string]string{"a": "1", "b": "1", "c": "9"}
	got, err := folderOrgs(projects, 2, func(projectID string) (string, error) {
		calls[projectID]++
		return orgOf[projectID], nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if want := map[string]string{"2": "1", "3": "9"}; !reflect.DeepEqual(got, want) {
		t.Errorf("folderOrgs() = %v, want %v", got, want)
	}
	if len(calls) != 2 {
		t.Errorf("folderOrgs() made %d lookups, want 2", len(calls))
	}
}

func TestFolderOrgsReturnsLookupErrors(t *testing.T) {
	projects := []gcpProject{project("a", "", "folder", "2")}
	_, err := folderOrgs(projects, 2, func(string) (string, error) { return "", errors.New("denied") })
	if err == nil {
		t.Error("folderOrgs() error = nil, want denied")
	}
}

func TestProjectGroupsSplitsProjectsByOrg(t *testing.T) {
	projects := []gcpProject{
		project("zed-prod", "Zed", "folder", "2"),
		project("api-dev", "", "organization", "1"),
		project("other", "Other", "organization", "9"),
		project("other-folder", "Other folder", "folder", "3"),
		project("orphan", "Orphan", "", ""),
		project("sys-123", "Apps Script", "organization", "1"),
		project("web", "Web", "organization", "5"),
	}
	got := projectGroups(projects, map[string]string{"2": "1", "3": "9"}, map[string]string{"1": "example.com", "5": "other.org"})
	want := map[string]snippetGroup{
		"1": {
			Name:     "GCP - Project - example.com",
			Snippets: []snippet{{Desc: "api-dev", Text: "api-dev"}, {Desc: "Zed", Text: "zed-prod"}},
		},
		"5": {
			Name:     "GCP - Project - other.org",
			Snippets: []snippet{{Desc: "Web", Text: "web"}},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("projectGroups() = %v, want %v", got, want)
	}
}

func TestProjectsFileSanitizesTheOrgName(t *testing.T) {
	tests := map[string]string{
		"example.com":    "gcp-projects-example.com.json",
		"My Org / Tests": "gcp-projects-my-org-tests.json",
	}
	for name, want := range tests {
		if got := projectsFile(name); got != want {
			t.Errorf("projectsFile(%q) = %q, want %q", name, got, want)
		}
	}
}

func TestRemoveStaleFilesKeepsWrittenFiles(t *testing.T) {
	dir := t.TempDir()
	for _, file := range []string{"gcp-projects-a.json", "gcp-projects-b.json", "coworkers-github.json"} {
		if err := os.WriteFile(filepath.Join(dir, file), []byte("{}"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := removeStaleFiles(dir, gcpProjectsFilePrefix, map[string]bool{"gcp-projects-a.json": true}); err != nil {
		t.Fatal(err)
	}
	entries, _ := os.ReadDir(dir)
	var got []string
	for _, entry := range entries {
		got = append(got, entry.Name())
	}
	if want := []string{"coworkers-github.json", "gcp-projects-a.json"}; !reflect.DeepEqual(got, want) {
		t.Errorf("files = %v, want %v", got, want)
	}
}

func TestOrgGroupMapsNamesToIDs(t *testing.T) {
	got := orgGroup([]gcpOrg{
		{Name: "organizations/2", DisplayName: "example.com"},
		{Name: "organizations/1", DisplayName: ""},
	})
	want := snippetGroup{
		Name:     "GCP - Organization",
		Snippets: []snippet{{Desc: "1", Text: "1"}, {Desc: "example.com", Text: "2"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("orgGroup() = %v, want %v", got, want)
	}
}

func TestBillingGroupKeepsOpenAccounts(t *testing.T) {
	got := billingGroup([]gcpBillingAccount{
		{Name: "billingAccounts/AAA-BBB", DisplayName: "Main", Open: true},
		{Name: "billingAccounts/CCC-DDD", DisplayName: "Closed", Open: false},
		{Name: "billingAccounts/EEE-FFF", DisplayName: "", Open: true},
	})
	want := snippetGroup{
		Name:     "GCP - Billing Account",
		Snippets: []snippet{{Desc: "EEE-FFF", Text: "EEE-FFF"}, {Desc: "Main", Text: "AAA-BBB"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("billingGroup() = %v, want %v", got, want)
	}
}
