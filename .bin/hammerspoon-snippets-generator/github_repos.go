// Repositories of the organizations returned by gh org list, a file per organization, archived ones left out.
// The repositories of the organizations are fetched concurrently.
package main

import (
	"fmt"
	"strings"
	"sync"
)

const (
	// githubReposGroupPrefix and githubReposFilePrefix are followed by the organization, a file per organization.
	githubReposGroupPrefix = "GitHub - Repo - "
	githubReposFilePrefix  = "github-repos-"
)

// listGitHubRepos returns the <org>/<repo> names of the repositories of org that are not archived.
func listGitHubRepos(org string) ([]string, error) {
	out, err := run("gh", "api", "--paginate", "orgs/"+org+"/repos?per_page=100",
		"--jq", ".[] | select(.archived | not) | .full_name")
	if err != nil {
		return nil, err
	}
	return strings.Fields(string(out)), nil
}

// repoGroup returns a snippet per repository of org, <repo> as description and <org>/<repo> as text, the
// organization being in the group name.
func repoGroup(org string, repos []string) snippetGroup {
	snippets := make([]snippet, 0, len(repos))
	for _, repo := range repos {
		snippets = append(snippets, snippet{Desc: strings.TrimPrefix(repo, org+"/"), Text: repo})
	}
	return newGroup(githubReposGroupPrefix+org, snippets)
}

// generateGitHubRepos writes the repositories of each organization of the authenticated user to dir, removing the
// files of the organizations the user left. No file is written when an organization fails.
func generateGitHubRepos(dir string) error {
	orgs, err := listGitHubOrgs()
	if err != nil {
		return err
	}
	repos := make([][]string, len(orgs))
	errs := make([]error, len(orgs))
	var wg sync.WaitGroup
	for i, org := range orgs {
		wg.Go(func() { repos[i], errs[i] = listGitHubRepos(org) })
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			return fmt.Errorf("fetching the repositories of %s: %w", orgs[i], err)
		}
	}
	written := map[string]bool{}
	for i, org := range orgs {
		if len(repos[i]) == 0 {
			continue
		}
		file := safeFileName(githubReposFilePrefix, org)
		if err := write(dir, file, repoGroup(org, repos[i])); err != nil {
			return err
		}
		written[file] = true
	}
	return removeStaleFiles(dir, githubReposFilePrefix, written)
}
