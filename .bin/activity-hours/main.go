package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"
)

// activityLogger is the Hammerspoon logger id that records screen lock and unlock events.
const activityLogger = "activity"

type event struct {
	Logger    string    `json:"logger"`
	Type      string    `json:"type"`
	Timestamp time.Time `json:"timestamp"`
}

// isLockEvent reports whether e is a screen lock or unlock recorded by the activity logger.
func isLockEvent(e event) bool {
	return e.Logger == activityLogger && (e.Type == "lock" || e.Type == "unlock")
}

type dayTotal struct {
	day      time.Time
	duration time.Duration
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to resolve home directory: %w", err)
	}
	path := flag.String("file", filepath.Join(home, "Library", "Logs", "hammerspoon", "logs.jsonl"), "JSON Lines file of lock/unlock events")
	days := flag.Int("days", 7, "number of days to show, including today")
	flag.Parse()

	file, err := os.Open(*path)
	if err != nil {
		return fmt.Errorf("failed to open %s: %w", *path, err)
	}
	defer file.Close()

	events, err := parseEvents(file)
	if err != nil {
		return fmt.Errorf("failed to parse %s: %w", *path, err)
	}

	var total time.Duration
	for _, day := range sumUnlocked(events, time.Now(), *days) {
		fmt.Printf("%s  %s\n", day.day.Format("Mon 2006-01-02"), formatDuration(day.duration))
		total += day.duration
	}
	fmt.Printf("%-14s  %s\n", "Total", formatDuration(total))
	return nil
}

// parseEvents reads one JSON entry per line and keeps only lock and unlock events, skipping blank lines and other log entries.
func parseEvents(reader io.Reader) ([]event, error) {
	var events []event
	scanner := bufio.NewScanner(reader)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 {
			continue
		}
		var e event
		if err := json.Unmarshal(line, &e); err != nil {
			return nil, fmt.Errorf("line %d: %w", lineNumber, err)
		}
		if isLockEvent(e) {
			events = append(events, e)
		}
	}
	return events, scanner.Err()
}

// sumUnlocked returns the unlocked duration for each of the last `days` local days ending on `now`, oldest first.
// An unlock without a following lock is counted as unlocked until `now`.
func sumUnlocked(events []event, now time.Time, days int) []dayTotal {
	today := startOfDay(now)
	totals := make([]dayTotal, days)
	for i := range totals {
		totals[i].day = today.AddDate(0, 0, i-days+1)
	}

	var unlockedAt *time.Time
	for _, e := range events {
		switch e.Type {
		case "unlock":
			if unlockedAt == nil {
				start := e.Timestamp.Local()
				unlockedAt = &start
			}
		case "lock":
			if unlockedAt != nil {
				addInterval(totals, *unlockedAt, e.Timestamp.Local())
				unlockedAt = nil
			}
		}
	}
	if unlockedAt != nil {
		addInterval(totals, *unlockedAt, now)
	}
	return totals
}

// addInterval splits the interval at local midnights and adds each part to its matching day.
func addInterval(totals []dayTotal, start, end time.Time) {
	for i := range totals {
		dayStart := totals[i].day
		dayEnd := dayStart.AddDate(0, 0, 1)
		overlapStart := later(start, dayStart)
		overlapEnd := earlier(end, dayEnd)
		if overlapEnd.After(overlapStart) {
			totals[i].duration += overlapEnd.Sub(overlapStart)
		}
	}
}

func startOfDay(t time.Time) time.Time {
	year, month, day := t.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, t.Location())
}

func later(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}

func earlier(a, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}

func formatDuration(d time.Duration) string {
	minutes := int(d.Round(time.Minute).Minutes())
	return fmt.Sprintf("%2dh%02dm", minutes/60, minutes%60)
}
