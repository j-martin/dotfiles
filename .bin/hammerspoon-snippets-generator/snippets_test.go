package main

import "testing"

func TestWriteJSONSkipsUnchangedContent(t *testing.T) {
	path := t.TempDir() + "/snippets.json"
	value := []snippet{{Desc: "Jane Doe", Text: "jdoe"}}
	if written, err := writeJSON(path, value); err != nil || !written {
		t.Fatalf("first writeJSON() = %v, %v, want true, nil", written, err)
	}
	if written, err := writeJSON(path, value); err != nil || written {
		t.Errorf("second writeJSON() = %v, %v, want false, nil", written, err)
	}
}
