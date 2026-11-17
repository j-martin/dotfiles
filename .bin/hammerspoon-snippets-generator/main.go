// Writes Hammerspoon snippet groups, one JSON file each, loaded from the output directory by ~/.hammerspoon/snippets:
//   - coworkers-github-<organization>.json and coworkers-email-<organization>.json, the members of each organization
//     listed by gh, see github.go.
//   - github-repos-<organization>.json, the repositories of each organization listed by gh, see github_repos.go.
//   - github-teams-<organization>.json, the teams of each organization listed by gh, see github_teams.go.
//   - gcp-organizations.json, gcp-billing-accounts.json and gcp-projects-<organization>.json, the GCP organizations
//     and billing accounts visible to gcloud, and the projects of each organization, see gcp.go.
//   - gcp-regions.json and gcp-zones.json, the GCP regions and zones of Canada and the US, see gcp_zones.go.
//   - gcp-dns-records.json, the Cloud DNS records of the projects with dns in their ID or name, see gcp_dns.go.
//
// Each source is optional and generated concurrently, a failing one does not prevent writing the others.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
)

func main() {
	outputDir := flag.String("output-dir", "", "Directory of the JSON files to write (required)")
	flag.Parse()
	if *outputDir == "" {
		flag.Usage()
		os.Exit(2)
	}
	github := commandAvailable("gh")
	gcp := commandAvailable("gcloud")
	if !github && !gcp {
		fmt.Println("No snippet sources available; skipping")
		return
	}

	var mu sync.Mutex
	var failed []string
	var wg sync.WaitGroup
	generate := func(source string, fn func() error) {
		wg.Go(func() {
			if err := fn(); err != nil {
				log.Printf("%s: %v", source, err)
				mu.Lock()
				failed = append(failed, source)
				mu.Unlock()
			}
		})
	}
	if github {
		generate("github", func() error { return generateGitHub(*outputDir) })
		generate("github-repos", func() error { return generateGitHubRepos(*outputDir) })
		generate("github-teams", func() error { return generateGitHubTeams(*outputDir) })
	}
	if gcp {
		generate("gcp", func() error { return generateGCP(*outputDir) })
		generate("gcp-zones", func() error { return generateGCPZones(*outputDir) })
		generate("gcp-dns", func() error { return generateGCPDNS(*outputDir) })
	}
	wg.Wait()
	if len(failed) > 0 {
		fmt.Fprintf(os.Stderr, "failed: %s\n", strings.Join(failed, ", "))
		os.Exit(1)
	}
}

func commandAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
