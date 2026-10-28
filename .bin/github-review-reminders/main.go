// Syncs the GitHub pull requests awaiting my review to macOS Reminders.
//
// Uses the same filter as ric: open, non-draft pull requests requested from me that nobody
// reviewed yet, excluding the repositories in RIC_IGNORED_REPOSITORIES.
//
// Each reminder note starts with the marker and the pull request URL, which identifies it,
// e.g. "github-review-reminders <https://github.com/o/r/pull/1>". Reminders without the marker
// are never changed. A reminder is
// created when a pull request matches, completed once it no longer matches, and reopened
// when it matches again.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

type pullRequest struct {
	URL        string `json:"url"`
	Title      string `json:"title"`
	Number     int    `json:"number"`
	Repository struct {
		NameWithOwner string `json:"nameWithOwner"`
	} `json:"repository"`
	Author struct {
		Login string `json:"login"`
	} `json:"author"`
}

type reminder struct {
	ID        string `json:"id"`
	Body      string `json:"body"`
	Completed bool   `json:"completed"`
}

type newReminder struct {
	Title string `json:"title"`
	Notes string `json:"notes"`
}

type changes struct {
	List     string        `json:"list"`
	Create   []newReminder `json:"create"`
	Complete []string      `json:"complete"`
	Reopen   []string      `json:"reopen"`
}

const marker = "github-review-reminders"

// Reminders turns hashtags in the notes into tags.
const tag = "#github"

var noteID = regexp.MustCompile(`^` + marker + ` <(https://github\.com/[^/\s]+/[^/\s]+/pull/\d+)>$`)

// Returns the reminders of the list whose note starts with the marker.
const fetchScript = `
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = p.list ? app.lists.byName(p.list) : app.defaultList;
  const matches = list.reminders.whose({body: {_beginsWith: p.prefix}});
  const ids = matches.id();
  const bodies = matches.body();
  const completed = matches.completed();
  return JSON.stringify(ids.map((id, i) => ({id, body: bodies[i], completed: completed[i]})));
}
`

const applyScript = `
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = p.list ? app.lists.byName(p.list) : app.defaultList;
  for (const r of p.create) {
    list.reminders.push(app.Reminder({name: r.title, body: r.notes}));
  }
  for (const id of p.complete) {
    list.reminders.byId(id).completed = true;
  }
  for (const id of p.reopen) {
    list.reminders.byId(id).completed = false;
  }
  return '';
}
`

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	list := flag.String("list", "", "Reminders list, the default list when empty")
	query := flag.String("query", "is:pr is:open draft:false archived:false review-requested:@me review:none", "GitHub search query for the pull requests to review")
	dryRun := flag.Bool("dry-run", false, "print the changes without applying them")
	flag.Parse()

	var requested []pullRequest
	args := append([]string{"search", "prs", "--limit", "200", "--json", "url,title,number,repository,author", "--"}, strings.Fields(*query)...)
	args = append(args, ignoredReposQualifiers(os.Getenv("RIC_IGNORED_REPOSITORIES"))...)
	if err := runJSON(&requested, "gh", args...); err != nil {
		return fmt.Errorf("failed to search pull requests: %w", err)
	}

	var reminders []reminder
	if err := runJSON(&reminders, "osascript", "-l", "JavaScript", "-e", fetchScript, mustJSON(map[string]string{"list": *list, "prefix": marker + " <"})); err != nil {
		return fmt.Errorf("failed to read reminders: %w", err)
	}

	c := plan(requested, reminders)
	c.List = *list

	for _, r := range c.Create {
		log.Printf("create: %s", r.Title)
	}
	log.Printf("%d requested, %d created, %d completed, %d reopened", len(requested), len(c.Create), len(c.Complete), len(c.Reopen))
	if *dryRun || len(c.Create)+len(c.Complete)+len(c.Reopen) == 0 {
		return nil
	}
	if _, err := output("osascript", "-l", "JavaScript", "-e", applyScript, mustJSON(c)); err != nil {
		return fmt.Errorf("failed to update reminders: %w", err)
	}
	return nil
}

// Returns the reminders to create or reopen for the requested pull requests, and to complete
// for the pull requests no longer requested.
func plan(requested []pullRequest, reminders []reminder) changes {
	byURL := map[string][]reminder{}
	for _, r := range reminders {
		if url := noteURL(r.Body); url != "" {
			byURL[url] = append(byURL[url], r)
		}
	}

	c := changes{Create: []newReminder{}, Complete: []string{}, Reopen: []string{}}
	isRequested := map[string]bool{}
	for _, pr := range requested {
		isRequested[pr.URL] = true
		existing := byURL[pr.URL]
		switch {
		case len(existing) == 0:
			c.Create = append(c.Create, newReminder{
				Title: fmt.Sprintf("👀 Review %s#%d: %s", pr.Repository.NameWithOwner, pr.Number, pr.Title),
				Notes: fmt.Sprintf("%s <%s>\n\nby %s\n\n%s", marker, pr.URL, pr.Author.Login, tag),
			})
		case !hasOpen(existing):
			c.Reopen = append(c.Reopen, existing[0].ID)
		}
	}

	for url, rs := range byURL {
		if isRequested[url] {
			continue
		}
		for _, r := range rs {
			if !r.Completed {
				c.Complete = append(c.Complete, r.ID)
			}
		}
	}
	return c
}

// Returns the pull request URL following the marker on the first line of the note, or "" when
// there is none.
func noteURL(body string) string {
	line, _, _ := strings.Cut(body, "\n")
	match := noteID.FindStringSubmatch(strings.TrimSpace(line))
	if match == nil {
		return ""
	}
	return match[1]
}

func hasOpen(reminders []reminder) bool {
	for _, r := range reminders {
		if !r.Completed {
			return true
		}
	}
	return false
}

// Converts a comma-separated list of OWNER/REPO into GitHub search exclusion qualifiers.
func ignoredReposQualifiers(value string) []string {
	var qualifiers []string
	for _, repo := range strings.Split(value, ",") {
		if repo = strings.TrimSpace(repo); repo != "" {
			qualifiers = append(qualifiers, "-repo:"+repo)
		}
	}
	return qualifiers
}

func runJSON(v any, name string, args ...string) error {
	out, err := output(name, args...)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(out, v); err != nil {
		return fmt.Errorf("failed to parse the output of %s: %w", name, err)
	}
	return nil
}

func output(name string, args ...string) ([]byte, error) {
	var stderr bytes.Buffer
	cmd := exec.Command(name, args...)
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("%s: %w: %s", name, err, strings.TrimSpace(stderr.String()))
	}
	return out, nil
}

func mustJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return string(b)
}
