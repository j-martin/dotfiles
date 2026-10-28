package main

import (
	"strings"
	"testing"
	"time"
)

func at(value string) time.Time {
	t, err := time.ParseInLocation("2006-01-02 15:04", value, time.Local)
	if err != nil {
		panic(err)
	}
	return t
}

func totalsByDay(totals []dayTotal) map[string]time.Duration {
	result := map[string]time.Duration{}
	for _, total := range totals {
		result[total.day.Format("2006-01-02")] = total.duration
	}
	return result
}

func TestSumUnlockedSumsIntervalsOnSameDay(t *testing.T) {
	events := []event{
		{Type: "unlock", Timestamp: at("2026-10-16 09:00")},
		{Type: "lock", Timestamp: at("2026-10-16 10:30")},
		{Type: "unlock", Timestamp: at("2026-10-16 13:00")},
		{Type: "lock", Timestamp: at("2026-10-16 14:00")},
	}

	got := totalsByDay(sumUnlocked(events, at("2026-10-16 20:00"), 7))["2026-10-16"]

	if got != 150*time.Minute {
		t.Errorf("expected 2h30m, got %s", got)
	}
}

func TestSumUnlockedSplitsIntervalAcrossMidnight(t *testing.T) {
	events := []event{
		{Type: "unlock", Timestamp: at("2026-10-15 23:00")},
		{Type: "lock", Timestamp: at("2026-10-16 01:00")},
	}

	got := totalsByDay(sumUnlocked(events, at("2026-10-16 20:00"), 7))

	if got["2026-10-15"] != time.Hour || got["2026-10-16"] != time.Hour {
		t.Errorf("expected 1h on each day, got %v", got)
	}
}

func TestSumUnlockedCountsOpenIntervalUntilNow(t *testing.T) {
	events := []event{
		{Type: "unlock", Timestamp: at("2026-10-16 18:00")},
	}

	got := totalsByDay(sumUnlocked(events, at("2026-10-16 20:00"), 7))["2026-10-16"]

	if got != 2*time.Hour {
		t.Errorf("expected 2h, got %s", got)
	}
}

func TestSumUnlockedIgnoresUnmatchedLock(t *testing.T) {
	events := []event{
		{Type: "lock", Timestamp: at("2026-10-16 08:00")},
		{Type: "unlock", Timestamp: at("2026-10-16 09:00")},
		{Type: "lock", Timestamp: at("2026-10-16 10:00")},
		{Type: "lock", Timestamp: at("2026-10-16 11:00")},
	}

	got := totalsByDay(sumUnlocked(events, at("2026-10-16 20:00"), 7))["2026-10-16"]

	if got != time.Hour {
		t.Errorf("expected 1h, got %s", got)
	}
}

func TestSumUnlockedReturnsOnlyRequestedDaysOldestFirst(t *testing.T) {
	events := []event{
		{Type: "unlock", Timestamp: at("2026-10-01 09:00")},
		{Type: "lock", Timestamp: at("2026-10-01 10:00")},
	}

	totals := sumUnlocked(events, at("2026-10-16 20:00"), 7)

	if len(totals) != 7 {
		t.Fatalf("expected 7 days, got %d", len(totals))
	}
	first := totals[0].day.Format("2006-01-02")
	last := totals[6].day.Format("2006-01-02")
	if first != "2026-10-10" || last != "2026-10-16" {
		t.Errorf("expected 2026-10-10..2026-10-16, got %s..%s", first, last)
	}
}

func TestParseEventsReadsJSONLines(t *testing.T) {
	input := `{"logger":"activity","type":"lock","timestamp":"2026-10-16T16:53:42-07:00"}

{"logger":"activity","type":"unlock","timestamp":"2026-10-16T23:53:45Z"}
`

	events, err := parseEvents(strings.NewReader(input))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(events) != 2 || events[1].Type != "unlock" {
		t.Errorf("unexpected events: %+v", events)
	}
}

func TestParseEventsReportsLineNumberOnInvalidJSON(t *testing.T) {
	_, err := parseEvents(strings.NewReader("{\"type\":\"lock\"}\nnot json\n"))

	if err == nil || !strings.Contains(err.Error(), "line 2") {
		t.Errorf("expected error mentioning line 2, got %v", err)
	}
}

func TestParseEventsKeepsOnlyActivityLockEvents(t *testing.T) {
	input := `{"logger":"activity","type":"unlock","timestamp":"2026-10-16T09:00:00-07:00"}
{"logger":"meetingbar","level":"info","message":"Restarting MeetingBar","timestamp":"2026-10-16T09:01:00-07:00"}
{"logger":"other","type":"lock","timestamp":"2026-10-16T09:30:00-07:00"}
{"logger":"activity","type":"wake","timestamp":"2026-10-16T09:45:00-07:00"}
{"logger":"activity","type":"lock","timestamp":"2026-10-16T10:00:00-07:00"}
`

	events, err := parseEvents(strings.NewReader(input))

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(events) != 2 || events[0].Type != "unlock" || events[1].Type != "lock" {
		t.Errorf("expected only the activity unlock and lock, got %+v", events)
	}
}
