// Teams of the organizations returned by gh org list, a file per organization, inserted as @<org>/<team> mentions.
// The teams of the organizations are fetched concurrently.
package main

import (
	"fmt"
	"strings"
	"sync"
)

const (
	// githubTeamsGroupPrefix and githubTeamsFilePrefix are followed by the organization, a file per organization.
	githubTeamsGroupPrefix = "GitHub - Team - "
	githubTeamsFilePrefix  = "github-teams-"
)

// team is a team of an organization, its slug used in mentions and its name shown in the picker.
type team struct {
	Slug string
	Name string
}

// listGitHubTeams returns the teams of org visible to the authenticated user.
func listGitHubTeams(org string) ([]team, error) {
	out, err := run("gh", "api", "--paginate", "orgs/"+org+"/teams?per_page=100",
		"--jq", `.[] | "\(.slug)\t\(.name)"`)
	if err != nil {
		return nil, err
	}
	var teams []team
	for line := range strings.Lines(string(out)) {
		slug, name, _ := strings.Cut(strings.TrimRight(line, "\r\n"), "\t")
		if slug == "" {
			continue
		}
		if name == "" {
			name = slug
		}
		teams = append(teams, team{Slug: slug, Name: name})
	}
	return teams, nil
}

// teamGroup returns a snippet per team of org, its name as description and @<org>/<slug> as text.
func teamGroup(org string, teams []team) snippetGroup {
	snippets := make([]snippet, 0, len(teams))
	for _, t := range teams {
		snippets = append(snippets, snippet{Desc: t.Name, Text: "@" + org + "/" + t.Slug})
	}
	return newGroup(githubTeamsGroupPrefix+org, snippets)
}

// generateGitHubTeams writes the teams of each organization of the authenticated user to dir, removing the files of
// the organizations the user left. No file is written when an organization fails.
func generateGitHubTeams(dir string) error {
	orgs, err := listGitHubOrgs()
	if err != nil {
		return err
	}
	teams := make([][]team, len(orgs))
	errs := make([]error, len(orgs))
	var wg sync.WaitGroup
	for i, org := range orgs {
		wg.Go(func() { teams[i], errs[i] = listGitHubTeams(org) })
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			return fmt.Errorf("fetching the teams of %s: %w", orgs[i], err)
		}
	}
	written := map[string]bool{}
	for i, org := range orgs {
		if len(teams[i]) == 0 {
			continue
		}
		file := safeFileName(githubTeamsFilePrefix, org)
		if err := write(dir, file, teamGroup(org, teams[i])); err != nil {
			return err
		}
		written[file] = true
	}
	return removeStaleFiles(dir, githubTeamsFilePrefix, written)
}
