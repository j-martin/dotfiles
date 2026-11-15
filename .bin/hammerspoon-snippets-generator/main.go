// Writes Hammerspoon snippet groups, one JSON file each, loaded from the output directory by ~/.hammerspoon/snippets:
//   - coworkers-github.json and coworkers-email.json, the members of a GitHub organization, see github.go.
//   - gcp-organizations.json, gcp-billing-accounts.json and gcp-projects-<organization>.json, the GCP organizations
//     and billing accounts visible to gcloud, and the projects of each organization, see gcp.go.
//
// Each source is optional and generated concurrently, a failing one does not prevent writing the others.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
)

func main() {
	outputDir := flag.String("output-dir", "", "Directory of the JSON files to write (required)")
	githubOrg := flag.String("github-org", "", "GitHub organization whose members become snippets")
	gcp := flag.Bool("gcp", false, "Generate the GCP organizations, billing accounts and projects visible to gcloud")
	flag.Parse()
	if *outputDir == "" || (*githubOrg == "" && !*gcp) {
		flag.Usage()
		os.Exit(2)
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
	if *githubOrg != "" {
		generate("github", func() error { return generateGitHub(*outputDir, *githubOrg) })
	}
	if *gcp {
		generate("gcp", func() error { return generateGCP(*outputDir) })
	}
	wg.Wait()
	if len(failed) > 0 {
		fmt.Fprintf(os.Stderr, "failed: %s\n", strings.Join(failed, ", "))
		os.Exit(1)
	}
}
