// Syncs the Jira issues matching a JQL query to macOS Reminders.
//
// By default, the unresolved issues assigned to me, except those in Inbox or Backlog not updated in
// the last 2 weeks. Jira is queried with the REST API using the "url"
// (e.g. https://example.atlassian.net), "username" and "password" (API token) entries of the "jira"
// keyring service, e.g. `keyring get jira password`.
//
// Each reminder note starts with the marker and the issue URL, which identifies it,
// e.g. "jira-reminders <https://example.atlassian.net/browse/ABC-1>". Reminders without the
// marker are never changed. A reminder is created when an issue matches, completed once it no
// longer matches, and reopened when it matches again. Its title, which includes the Jira status,
// is updated when the issue changes.
//
// Reminders completed because their issue no longer matches get a note line, see autoCompleted.
// A matching issue whose reminders are all completed without that line is transitioned to Done,
// and one whose open reminder title ends with a standalone "p" is transitioned to In Progress.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/zalando/go-keyring"
)

type issue struct {
	Key    string `json:"key"`
	Fields struct {
		Summary string `json:"summary"`
		Status  struct {
			Name string `json:"name"`
		} `json:"status"`
	} `json:"fields"`
}

type searchResponse struct {
	Issues        []issue `json:"issues"`
	NextPageToken string  `json:"nextPageToken"`
	IsLast        bool    `json:"isLast"`
}

type reminder struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Body      string `json:"body"`
	Completed bool   `json:"completed"`
}

type newReminder struct {
	Title string `json:"title"`
	Notes string `json:"notes"`
	URL   string `json:"-"`
}

type rename struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	URL   string `json:"-"`
}

type renote struct {
	ID    string `json:"id"`
	Notes string `json:"notes"`
}

type changes struct {
	List     string        `json:"list"`
	Create   []newReminder `json:"create"`
	Complete []renote      `json:"complete"`
	Reopen   []renote      `json:"reopen"`
	Rename   []rename      `json:"rename"`
}

type transitionRequest struct {
	Key    string
	Target string
}

const marker = "jira-reminders"

// Note line telling apart the reminders completed by this program from those completed by me.
const autoCompleted = marker + ": completed as the issue no longer matches"

const (
	statusDone       = "Done"
	statusInProgress = "In Progress"
)

// Suffix of a reminder title requesting to move its issue to In Progress.
const inProgressSuffix = " p"

// Reminders turns hashtags in the notes into tags.
const tag = "#jira"

var noteID = regexp.MustCompile(`^` + marker + ` <(https://\S+/browse/[A-Z][A-Z0-9_]*-\d+)>$`)

// Reminders list used when no list is given and there is no default list.
const fallbackList = "Work"

// Returns the list named name, or the default list when name is empty, or the fallback list when
// there is no default list.
const resolveListScript = `
function resolveList(app, name) {
  if (name) {
    const list = app.lists.byName(name);
    if (!list.exists()) {
      throw new Error('Reminders list not found: ' + name);
    }
    return list;
  }
  if (app.defaultList.exists()) {
    return app.defaultList;
  }
  const fallback = app.lists.byName('` + fallbackList + `');
  if (!fallback.exists()) {
    throw new Error('No default Reminders list and no list named ` + fallbackList + `');
  }
  return fallback;
}
`

// Returns the reminders of the list whose note starts with the marker.
const fetchScript = resolveListScript + `
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = resolveList(app, p.list);
  const matches = list.reminders.whose({body: {_beginsWith: p.prefix}});
  const ids = matches.id();
  const names = matches.name();
  const bodies = matches.body();
  const completed = matches.completed();
  return JSON.stringify(ids.map((id, i) => ({id, name: names[i], body: bodies[i], completed: completed[i]})));
}
`

const applyScript = resolveListScript + `
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = resolveList(app, p.list);
  for (const r of p.create) {
    list.reminders.push(app.Reminder({name: r.title, body: r.notes}));
  }
  for (const r of p.complete) {
    const reminder = list.reminders.byId(r.id);
    reminder.body = r.notes;
    reminder.completed = true;
  }
  for (const r of p.reopen) {
    const reminder = list.reminders.byId(r.id);
    reminder.body = r.notes;
    reminder.completed = false;
  }
  for (const r of p.rename) {
    list.reminders.byId(r.id).name = r.title;
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
	list := flag.String("list", "", "Reminders list, the default list (or "+fallbackList+" without one) when empty")
	jql := flag.String("jql", "assignee = currentUser() AND statusCategory != Done AND (status NOT IN (Inbox, Backlog) OR updated >= -2w)", "JQL query for the issues to remind")
	dryRun := flag.Bool("dry-run", false, "print the changes without applying them")
	flag.Parse()

	client, err := newJiraClient(keyring.Get)
	if err != nil {
		return err
	}
	issues, err := client.search(*jql)
	if err != nil {
		return fmt.Errorf("failed to search issues: %w", err)
	}

	var reminders []reminder
	if err := runJSON(&reminders, "osascript", "-l", "JavaScript", "-e", fetchScript, mustJSON(map[string]string{"list": *list, "prefix": marker + " <"})); err != nil {
		return fmt.Errorf("failed to read reminders: %w", err)
	}

	requests := planTransitions(client.baseURL, issues, reminders)
	var transitionErrs []error
	for _, r := range requests {
		log.Printf("transition: %s to %s", issueURL(client.baseURL, r.Key), r.Target)
		if *dryRun {
			continue
		}
		if err := client.transitionTo(r.Key, r.Target); err != nil {
			transitionErrs = append(transitionErrs, fmt.Errorf("failed to transition %s to %s: %w", r.Key, r.Target, err))
		}
	}
	if len(requests) > 0 && !*dryRun {
		if issues, err = client.search(*jql); err != nil {
			return fmt.Errorf("failed to search issues after the transitions: %w", err)
		}
	}

	c := plan(client.baseURL, issues, reminders)
	c.List = *list

	for _, r := range c.Create {
		log.Printf("create: %s %s", r.URL, r.Title)
	}
	for _, r := range c.Rename {
		log.Printf("rename: %s %s", r.URL, r.Title)
	}
	log.Printf("%d matching, %d created, %d completed, %d reopened, %d renamed", len(issues), len(c.Create), len(c.Complete), len(c.Reopen), len(c.Rename))
	if *dryRun || len(c.Create)+len(c.Complete)+len(c.Reopen)+len(c.Rename) == 0 {
		return errors.Join(transitionErrs...)
	}
	if _, err := output("osascript", "-l", "JavaScript", "-e", applyScript, mustJSON(c)); err != nil {
		return errors.Join(append(transitionErrs, fmt.Errorf("failed to update reminders: %w", err))...)
	}
	return errors.Join(transitionErrs...)
}

// Returns the transitions requested from the reminders of the matching issues: Done when all
// their reminders were completed by me, In Progress when an open reminder title ends with the
// in progress suffix.
func planTransitions(baseURL string, issues []issue, reminders []reminder) []transitionRequest {
	byURL := remindersByURL(reminders)
	requests := []transitionRequest{}
	for _, i := range issues {
		existing := byURL[issueURL(baseURL, i.Key)]
		if len(existing) == 0 {
			continue
		}
		open := firstOpen(existing)
		if open == nil {
			if !isAutoCompleted(existing[0].Body) {
				requests = append(requests, transitionRequest{Key: i.Key, Target: statusDone})
			}
			continue
		}
		if strings.HasSuffix(strings.TrimSpace(open.Name), inProgressSuffix) && !strings.EqualFold(i.Fields.Status.Name, statusInProgress) {
			requests = append(requests, transitionRequest{Key: i.Key, Target: statusInProgress})
		}
	}
	return requests
}

// Returns the reminders to create, reopen or rename for the matching issues, and to complete for
// the issues no longer matching. The completed reminders of matching issues are reopened only when
// completed by this program, the others are left to planTransitions.
func plan(baseURL string, issues []issue, reminders []reminder) changes {
	byURL := remindersByURL(reminders)
	c := changes{Create: []newReminder{}, Complete: []renote{}, Reopen: []renote{}, Rename: []rename{}}
	matching := map[string]bool{}
	for _, i := range issues {
		url := issueURL(baseURL, i.Key)
		matching[url] = true
		title := reminderTitle(i)
		existing := byURL[url]
		if len(existing) == 0 {
			c.Create = append(c.Create, newReminder{Title: title, Notes: fmt.Sprintf("%s <%s>\n\n%s", marker, url, tag), URL: url})
			continue
		}
		target := firstOpen(existing)
		if target == nil {
			if !isAutoCompleted(existing[0].Body) {
				continue
			}
			target = &existing[0]
			c.Reopen = append(c.Reopen, renote{ID: target.ID, Notes: withoutAutoCompleted(target.Body)})
		}
		if target.Name != title {
			c.Rename = append(c.Rename, rename{ID: target.ID, Title: title, URL: url})
		}
	}

	for url, rs := range byURL {
		if matching[url] {
			continue
		}
		for _, r := range rs {
			if !r.Completed {
				c.Complete = append(c.Complete, renote{ID: r.ID, Notes: withAutoCompleted(r.Body)})
			}
		}
	}
	return c
}

// Returns the reminders grouped by the issue URL of their note, ignoring those without one.
func remindersByURL(reminders []reminder) map[string][]reminder {
	byURL := map[string][]reminder{}
	for _, r := range reminders {
		if url := noteURL(r.Body); url != "" {
			byURL[url] = append(byURL[url], r)
		}
	}
	return byURL
}

// Returns whether the note says the reminder was completed by this program.
func isAutoCompleted(body string) bool {
	for line := range strings.Lines(body) {
		if strings.TrimSpace(line) == autoCompleted {
			return true
		}
	}
	return false
}

// Returns the note with the auto completed line appended.
func withAutoCompleted(body string) string {
	if isAutoCompleted(body) {
		return body
	}
	return strings.TrimRight(body, "\n") + "\n\n" + autoCompleted
}

// Returns the note without the auto completed line.
func withoutAutoCompleted(body string) string {
	var kept []string
	for line := range strings.Lines(body) {
		if strings.TrimSpace(line) != autoCompleted {
			kept = append(kept, line)
		}
	}
	return strings.TrimRight(strings.Join(kept, ""), "\n")
}

// Returns the browse URL of the issue.
func issueURL(baseURL, key string) string {
	return strings.TrimRight(baseURL, "/") + "/browse/" + key
}

// Returns the issue URL following the marker on the first line of the note, or "" when there
// is none.
func noteURL(body string) string {
	line, _, _ := strings.Cut(body, "\n")
	match := noteID.FindStringSubmatch(strings.TrimSpace(line))
	if match == nil {
		return ""
	}
	return match[1]
}

// Returns the reminder title of the issue, including its status.
func reminderTitle(i issue) string {
	return fmt.Sprintf("🎫 %s [%s]: %s", i.Key, i.Fields.Status.Name, i.Fields.Summary)
}

// Returns the first reminder not completed, or nil when they are all completed.
func firstOpen(reminders []reminder) *reminder {
	for i := range reminders {
		if !reminders[i].Completed {
			return &reminders[i]
		}
	}
	return nil
}

type jiraClient struct {
	baseURL string
	email   string
	token   string
	http    *http.Client
}

const keyringService = "jira"

// Returns a Jira client configured with the keyring entries read with get.
func newJiraClient(get func(service, user string) (string, error)) (*jiraClient, error) {
	values := map[string]string{}
	for _, name := range []string{"url", "username", "password"} {
		value, err := get(keyringService, name)
		if err != nil {
			return nil, fmt.Errorf("failed to read %q of the %q keyring service: %w", name, keyringService, err)
		}
		if value = strings.TrimSpace(value); value == "" {
			return nil, fmt.Errorf("%q of the %q keyring service is empty", name, keyringService)
		}
		values[name] = value
	}
	return &jiraClient{
		baseURL: strings.TrimRight(values["url"], "/"),
		email:   values["username"],
		token:   values["password"],
		http:    &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// Returns all the issues matching the JQL query, following the pagination.
func (c *jiraClient) search(jql string) ([]issue, error) {
	issues := []issue{}
	token := ""
	for {
		body := map[string]any{"jql": jql, "fields": []string{"summary", "status"}, "maxResults": 100}
		if token != "" {
			body["nextPageToken"] = token
		}
		var page searchResponse
		if err := c.do(http.MethodPost, "/rest/api/3/search/jql", body, &page); err != nil {
			return nil, err
		}
		issues = append(issues, page.Issues...)
		if page.IsLast || page.NextPageToken == "" {
			return issues, nil
		}
		token = page.NextPageToken
	}
}

type jiraTransition struct {
	ID string `json:"id"`
	To struct {
		Name           string `json:"name"`
		StatusCategory struct {
			Key string `json:"key"`
		} `json:"statusCategory"`
	} `json:"to"`
}

// Moves the issue to the target status with the first available transition leading to it.
func (c *jiraClient) transitionTo(key, target string) error {
	path := "/rest/api/3/issue/" + key + "/transitions"
	var available struct {
		Transitions []jiraTransition `json:"transitions"`
	}
	if err := c.do(http.MethodGet, path, nil, &available); err != nil {
		return err
	}
	t := pickTransition(available.Transitions, target)
	if t == nil {
		return fmt.Errorf("no transition to %q among %d available", target, len(available.Transitions))
	}
	return c.do(http.MethodPost, path, map[string]any{"transition": map[string]string{"id": t.ID}}, nil)
}

// Returns the transition leading to the target status, or nil when there is none. For Done,
// falls back to any transition leading to a status of the done category.
func pickTransition(transitions []jiraTransition, target string) *jiraTransition {
	for i := range transitions {
		if strings.EqualFold(transitions[i].To.Name, target) {
			return &transitions[i]
		}
	}
	if target != statusDone {
		return nil
	}
	for i := range transitions {
		if transitions[i].To.StatusCategory.Key == "done" {
			return &transitions[i]
		}
	}
	return nil
}

// Sends the request with the JSON body, when not nil, and decodes the JSON response into v, when
// not nil.
func (c *jiraClient) do(method, path string, body any, v any) error {
	var reader io.Reader
	if body != nil {
		reader = strings.NewReader(mustJSON(body))
	}
	req, err := http.NewRequest(method, c.baseURL+path, reader)
	if err != nil {
		return err
	}
	req.SetBasicAuth(c.email, c.token)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("%s %s: %s: %s", method, path, resp.Status, strings.TrimSpace(string(data)))
	}
	if v == nil {
		return nil
	}
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("failed to parse the response of %s: %w", path, err)
	}
	return nil
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
