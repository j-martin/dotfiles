package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"

	"github.com/ollama/ollama/api"
)

const model = "Gemma3n:e2b"

type mode struct {
	system string
	user   func(text string) string
}

var outputRules = strings.Join([]string{"OUTPUT RULES (STRICT):",
	"- Reply with ONLY the transformed text. Nothing else.",
	"- NEVER start with phrases like \"Here is\", \"Here's\", \"Sure\", \"Okay\", \"Certainly\", " +
		"\"I've\", \"I have\", \"Below is\", \"The revised text\", or any preamble.",
	"- NEVER end with commentary, notes, disclaimers, or offers of further help.",
	"- NEVER wrap the output in quotes, backticks, or Markdown code fences.",
	"- NEVER include a title, heading, or label.",
	"- Your first character must be the first character of the transformed text.",
	"- Your last character must be the last character of the transformed text.",
	"- Sentence case text",
}, "\n")

var modes = map[string]mode{
	"grammar": {
		system: "You are a meticulous copy editor. Correct grammar, spelling, and punctuation in the text the user provides. " +
			"Preserve the author's voice, tone, meaning, formatting, and language. Do not rephrase for style, do not add or remove content, " +
			"and do not translate.\n\n" + outputRules,
		user: func(text string) string {
			return "Correct the grammar, spelling, and punctuation of the following text. " +
				"Reply with only the corrected text.\n\n" + text
		},
	},
	"smoothen": {
		system: "You are a warm, friendly editor. Rewrite the text the user provides so it sounds friendlier, more approachable, and more positive, " +
			"while preserving the original meaning, key facts, language, and rough length. Do not add new content. Keep it professional, not sycophantic. " +
			"An occasional well-placed emoji is fine.\n\n" + outputRules,
		user: func(text string) string {
			return "Rewrite the following text with a friendlier, warmer tone while keeping the meaning intact.\n\n" + text
		},
	},
}

// preambleRe matches conversational lead-ins small models often prepend, e.g.
// "Here's a revised version of the text, aiming for a friendlier tone:" followed
// by one or more blank lines. Consumes through the terminating colon and newline.
var preambleRe = regexp.MustCompile(`(?is)\A\s*(?:sure|okay|ok|certainly|absolutely|of course|here(?:'s| is| are)|below is|i(?:'ve| have)|the (?:revised|rewritten|corrected|edited|updated|friendlier|following))\b[^\n]{0,200}:\s*\n+`)

// cleanOutput strips preamble sentences, surrounding quotes, and Markdown code fences.
func cleanOutput(s string) string {
	s = strings.TrimSpace(s)
	if m := preambleRe.FindString(s); m != "" {
		s = strings.TrimSpace(s[len(m):])
	}
	s = stripFences(s)
	s = stripWrappingQuotes(s)
	return strings.TrimSpace(s)
}

// stripFences removes a leading and trailing triple-backtick code fence if present.
func stripFences(s string) string {
	if !strings.HasPrefix(s, "```") {
		return s
	}
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		s = s[i+1:]
	}
	s = strings.TrimRight(s, "\n \t")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

// stripWrappingQuotes removes matching " or ' or “” or “ around the whole text.
func stripWrappingQuotes(s string) string {
	pairs := []struct{ l, r string }{
		{`"`, `"`}, {`'`, `'`}, {"`", "`"}, {"“", "”"}, {"‘", "’"},
	}
	for _, p := range pairs {
		if strings.HasPrefix(s, p.l) && strings.HasSuffix(s, p.r) && len(s) > len(p.l)+len(p.r) {
			return s[len(p.l) : len(s)-len(p.r)]
		}
	}
	return s
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) < 2 {
		return fmt.Errorf("usage: %s <grammar|smoothen> [text]", os.Args[0])
	}

	m, ok := modes[os.Args[1]]
	if !ok {
		return fmt.Errorf("unknown mode %q, expected grammar or smoothen", os.Args[1])
	}

	text, err := readInput()
	if err != nil {
		return err
	}
	if text == "" {
		return fmt.Errorf("no input text provided on stdin or as second argument")
	}

	client, err := api.ClientFromEnvironment()
	if err != nil {
		return fmt.Errorf("ollama client: %w", err)
	}

	ctx := context.Background()
	if err := ensureModel(ctx, client, model); err != nil {
		return err
	}

	stream := false
	req := &api.ChatRequest{
		Model:  model,
		Stream: &stream,
		Messages: []api.Message{
			{Role: "system", Content: m.system},
			{Role: "user", Content: m.user(text)},
		},
	}

	var buf strings.Builder
	err = client.Chat(ctx, req, func(resp api.ChatResponse) error {
		buf.WriteString(resp.Message.Content)
		return nil
	})
	if err != nil {
		return err
	}
	_, err = fmt.Fprintln(os.Stdout, cleanOutput(buf.String()))
	return err
}

// ensureModel checks whether the given model is available locally and pulls it if not.
func ensureModel(ctx context.Context, client *api.Client, name string) error {
	if _, err := client.Show(ctx, &api.ShowRequest{Model: name}); err == nil {
		return nil
	}

	fmt.Fprintf(os.Stderr, "pulling model %s...\n", name)
	var lastStatus string
	err := client.Pull(ctx, &api.PullRequest{Model: name}, func(resp api.ProgressResponse) error {
		if resp.Status == "" || resp.Status == lastStatus {
			return nil
		}
		lastStatus = resp.Status
		fmt.Fprintln(os.Stderr, resp.Status)
		return nil
	})
	if err != nil {
		return fmt.Errorf("pull %s: %w", name, err)
	}
	return nil
}

// readInput returns the second CLI argument when present, otherwise reads all of stdin.
func readInput() (string, error) {
	if len(os.Args) >= 3 {
		return os.Args[2], nil
	}
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return "", fmt.Errorf("read stdin: %w", err)
	}
	return string(data), nil
}
