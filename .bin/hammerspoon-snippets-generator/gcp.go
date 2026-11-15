// GCP organizations and open billing accounts visible to the gcloud account, and the projects of the organizations,
// including the ones in nested folders.
//
// A single `gcloud projects list` fetches every visible project, concurrently with the organizations. The organization of a folder comes from the
// ancestors of one of its projects, fetched concurrently, since listing or describing folders is often denied.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

// unsafeFileChars matches the characters replaced in file names.
var unsafeFileChars = regexp.MustCompile(`[^a-z0-9.-]+`)

const (
	// gcpProjectsGroupPrefix and gcpProjectsFilePrefix are followed by the organization, a file per organization.
	gcpProjectsGroupPrefix = "GCP - Project - "
	gcpProjectsFilePrefix  = "gcp-projects-"
	gcpOrgsGroupName       = "GCP - Organization"
	gcpOrgsFile            = "gcp-organizations.json"
	gcpBillingGroupName    = "GCP - Billing Account"
	gcpBillingFile         = "gcp-billing-accounts.json"
	// gcpWorkers limits the concurrent gcloud processes, each one being slow to start.
	gcpWorkers = 8
	// gcpIgnoredPrefix marks the projects Google creates, e.g. for Apps Script.
	gcpIgnoredPrefix = "sys-"
)

type gcpProject struct {
	ProjectID string `json:"projectId"`
	Name      string `json:"name"`
	Parent    struct {
		Type string `json:"type"`
		ID   string `json:"id"`
	} `json:"parent"`
}

type gcpOrg struct {
	// Name is the resource name, e.g. organizations/123.
	Name        string `json:"name"`
	DisplayName string `json:"displayName"`
}

// id returns the organization ID, e.g. organizations/123 -> 123.
func (o gcpOrg) id() string {
	return strings.TrimPrefix(o.Name, "organizations/")
}

func listOrgs() ([]gcpOrg, error) {
	out, err := run("gcloud", "organizations", "list", "--format=json")
	if err != nil {
		return nil, err
	}
	var orgs []gcpOrg
	if err := json.Unmarshal(out, &orgs); err != nil {
		return nil, fmt.Errorf("decoding the organizations: %w", err)
	}
	return orgs, nil
}

// orgGroup returns a snippet per organization, its display name as description and its ID as text.
func orgGroup(orgs []gcpOrg) snippetGroup {
	snippets := make([]snippet, 0, len(orgs))
	for _, org := range orgs {
		snippets = append(snippets, snippet{Desc: org.displayName(), Text: org.id()})
	}
	return newGroup(gcpOrgsGroupName, snippets)
}

// displayName returns the display name of the organization, its ID when it has none.
func (o gcpOrg) displayName() string {
	if o.DisplayName != "" {
		return o.DisplayName
	}
	return o.id()
}

type gcpBillingAccount struct {
	// Name is the resource name, e.g. billingAccounts/012345-6789AB-CDEF01.
	Name        string `json:"name"`
	DisplayName string `json:"displayName"`
	Open        bool   `json:"open"`
}

func listBillingAccounts() ([]gcpBillingAccount, error) {
	out, err := run("gcloud", "billing", "accounts", "list", "--format=json")
	if err != nil {
		return nil, err
	}
	var accounts []gcpBillingAccount
	if err := json.Unmarshal(out, &accounts); err != nil {
		return nil, fmt.Errorf("decoding the billing accounts: %w", err)
	}
	return accounts, nil
}

// billingGroup returns a snippet per open billing account, its display name as description and its ID as text.
func billingGroup(accounts []gcpBillingAccount) snippetGroup {
	var snippets []snippet
	for _, account := range accounts {
		if !account.Open {
			continue
		}
		id := strings.TrimPrefix(account.Name, "billingAccounts/")
		desc := account.DisplayName
		if desc == "" {
			desc = id
		}
		snippets = append(snippets, snippet{Desc: desc, Text: id})
	}
	return newGroup(gcpBillingGroupName, snippets)
}

func listProjects() ([]gcpProject, error) {
	out, err := run("gcloud", "projects", "list", "--filter=lifecycleState:ACTIVE", "--format=json")
	if err != nil {
		return nil, err
	}
	var projects []gcpProject
	if err := json.Unmarshal(out, &projects); err != nil {
		return nil, fmt.Errorf("decoding the projects: %w", err)
	}
	return projects, nil
}

// projectOrg returns the organization ID of a project from its ancestors, "" when it has none.
func projectOrg(projectID string) (string, error) {
	out, err := run("gcloud", "projects", "get-ancestors", projectID, "--format=json")
	if err != nil {
		return "", err
	}
	var ancestors []struct {
		ID   string `json:"id"`
		Type string `json:"type"`
	}
	if err := json.Unmarshal(out, &ancestors); err != nil {
		return "", fmt.Errorf("decoding the ancestors of %s: %w", projectID, err)
	}
	for _, ancestor := range ancestors {
		if ancestor.Type == "organization" {
			return ancestor.ID, nil
		}
	}
	return "", nil
}

// folderOrgs returns the organization ID of every folder holding projects, resolved from one of its projects
// with at most `workers` calls at once.
func folderOrgs(projects []gcpProject, workers int, orgOf func(projectID string) (string, error)) (map[string]string, error) {
	representatives := map[string]string{}
	for _, project := range projects {
		if project.Parent.Type == "folder" {
			if _, found := representatives[project.Parent.ID]; !found {
				representatives[project.Parent.ID] = project.ProjectID
			}
		}
	}
	orgs := make(map[string]string, len(representatives))
	var errs []error
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)
	for folder, projectID := range representatives {
		wg.Go(func() {
			sem <- struct{}{}
			defer func() { <-sem }()
			org, err := orgOf(projectID)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errs = append(errs, err)
				return
			}
			orgs[folder] = org
		})
	}
	wg.Wait()
	if len(errs) > 0 {
		return nil, errs[0]
	}
	return orgs, nil
}

// projectGroups returns a group per organization of orgs, keyed by ID with the display name as value, with a
// snippet per project, its name as description and its ID as text. The projects whose ID starts with
// gcpIgnoredPrefix are left out, as are the organizations without projects.
func projectGroups(projects []gcpProject, foldersOrg map[string]string, orgs map[string]string) map[string]snippetGroup {
	byOrg := map[string][]snippet{}
	for _, project := range projects {
		if strings.HasPrefix(project.ProjectID, gcpIgnoredPrefix) {
			continue
		}
		org := project.Parent.ID
		if project.Parent.Type == "folder" {
			org = foldersOrg[project.Parent.ID]
		} else if project.Parent.Type != "organization" {
			continue
		}
		if _, found := orgs[org]; !found {
			continue
		}
		name := project.Name
		if name == "" {
			name = project.ProjectID
		}
		byOrg[org] = append(byOrg[org], snippet{Desc: name, Text: project.ProjectID})
	}
	groups := make(map[string]snippetGroup, len(byOrg))
	for org, snippets := range byOrg {
		groups[org] = newGroup(gcpProjectsGroupPrefix+orgs[org], snippets)
	}
	return groups
}

// projectsFile returns the file of the projects of an organization, e.g. example.com -> gcp-projects-example.com.json.
func projectsFile(orgName string) string {
	return safeFileName(gcpProjectsFilePrefix, orgName)
}

// safeFileName returns the JSON file of prefix followed by name, lowercased with unsafe characters replaced,
// e.g. gcp-projects- and My Org -> gcp-projects-my-org.json.
func safeFileName(prefix, name string) string {
	return prefix + strings.Trim(unsafeFileChars.ReplaceAllString(strings.ToLower(name), "-"), "-.") + ".json"
}

// removeStaleFiles removes the files of dir starting with prefix that are not in keep, e.g. of a removed organization.
func removeStaleFiles(dir, prefix string, keep map[string]bool) error {
	paths, err := filepath.Glob(filepath.Join(dir, prefix+"*.json"))
	if err != nil {
		return err
	}
	for _, path := range paths {
		if !keep[filepath.Base(path)] {
			if err := os.Remove(path); err != nil {
				return err
			}
			fmt.Printf("Removed %s\n", path)
		}
	}
	return nil
}

// generateGCP writes the organizations and billing accounts visible to the gcloud account, and the projects of
// the organizations, to dir.
func generateGCP(dir string) error {
	var orgs []gcpOrg
	var projects []gcpProject
	var accounts []gcpBillingAccount
	var orgsErr, projectsErr, accountsErr error
	var wg sync.WaitGroup
	wg.Go(func() { orgs, orgsErr = listOrgs() })
	wg.Go(func() { projects, projectsErr = listProjects() })
	wg.Go(func() { accounts, accountsErr = listBillingAccounts() })
	wg.Wait()
	if orgsErr != nil {
		return orgsErr
	}
	if projectsErr != nil {
		return projectsErr
	}
	if accountsErr != nil {
		return accountsErr
	}
	if err := write(dir, gcpBillingFile, billingGroup(accounts)); err != nil {
		return err
	}
	if len(orgs) == 0 {
		return fmt.Errorf("no organizations visible to the gcloud account")
	}
	if err := write(dir, gcpOrgsFile, orgGroup(orgs)); err != nil {
		return err
	}
	foldersOrg, err := folderOrgs(projects, gcpWorkers, projectOrg)
	if err != nil {
		return err
	}
	names := make(map[string]string, len(orgs))
	for _, org := range orgs {
		names[org.id()] = org.displayName()
	}
	written := map[string]bool{}
	for org, group := range projectGroups(projects, foldersOrg, names) {
		file := projectsFile(names[org])
		if err := write(dir, file, group); err != nil {
			return err
		}
		written[file] = true
	}
	return removeStaleFiles(dir, gcpProjectsFilePrefix, written)
}
