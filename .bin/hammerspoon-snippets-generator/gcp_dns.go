// Cloud DNS records of the GCP projects with dns in their ID or name, inserted as FQDNs without the trailing dot.
// The zones of the projects, then the records of the zones, are fetched concurrently.
package main

import (
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"sync"
)

const (
	gcpDNSGroupName = "GCP - DNS Record"
	gcpDNSFile      = "gcp-dns-records.json"
	// gcpDNSProjectMarker is searched, ignoring case, in the project IDs and names.
	gcpDNSProjectMarker = "dns"
)

// gcpDNSZone is a Cloud DNS managed zone of a project.
type gcpDNSZone struct {
	Project string
	Name    string
}

// dnsProjects returns the IDs of the projects whose ID or name contains gcpDNSProjectMarker, ignoring case.
func dnsProjects(projects []gcpProject) []string {
	var ids []string
	for _, project := range projects {
		if strings.Contains(strings.ToLower(project.ProjectID), gcpDNSProjectMarker) ||
			strings.Contains(strings.ToLower(project.Name), gcpDNSProjectMarker) {
			ids = append(ids, project.ProjectID)
		}
	}
	return ids
}

// listDNSZones returns the managed zones of project.
func listDNSZones(project string) ([]gcpDNSZone, error) {
	out, err := run("gcloud", "dns", "managed-zones", "list", "--project="+project, "--format=json(name)")
	if err != nil {
		return nil, err
	}
	var decoded []struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(out, &decoded); err != nil {
		return nil, fmt.Errorf("decoding the DNS zones of %s: %w", project, err)
	}
	zones := make([]gcpDNSZone, 0, len(decoded))
	for _, zone := range decoded {
		zones = append(zones, gcpDNSZone{Project: project, Name: zone.Name})
	}
	return zones, nil
}

// gcpDNSRecord is a record set of a zone, its name having a trailing dot.
type gcpDNSRecord struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

// listDNSRecords returns the record sets of zone.
func listDNSRecords(zone gcpDNSZone) ([]gcpDNSRecord, error) {
	out, err := run("gcloud", "dns", "record-sets", "list", "--project="+zone.Project, "--zone="+zone.Name, "--format=json(name,type)")
	if err != nil {
		return nil, err
	}
	var records []gcpDNSRecord
	if err := json.Unmarshal(out, &records); err != nil {
		return nil, fmt.Errorf("decoding the records of %s/%s: %w", zone.Project, zone.Name, err)
	}
	return records, nil
}

// concurrentMap returns fn applied to every item, with at most workers calls at once, and the first error.
func concurrentMap[T, R any](items []T, workers int, fn func(T) (R, error)) ([]R, error) {
	results := make([]R, len(items))
	errs := make([]error, len(items))
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup
	for i, item := range items {
		wg.Go(func() {
			sem <- struct{}{}
			defer func() { <-sem }()
			results[i], errs[i] = fn(item)
		})
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	return results, nil
}

// dnsRecordGroup returns a snippet per distinct FQDN of records, without the trailing dot, as text, and the FQDN
// followed by its sorted record types as description, e.g. example.com (A, TXT).
func dnsRecordGroup(records []gcpDNSRecord) snippetGroup {
	types := map[string][]string{}
	for _, record := range records {
		fqdn := strings.TrimSuffix(record.Name, ".")
		if fqdn == "" {
			continue
		}
		if !slices.Contains(types[fqdn], record.Type) {
			types[fqdn] = append(types[fqdn], record.Type)
		}
	}
	snippets := make([]snippet, 0, len(types))
	for fqdn, fqdnTypes := range types {
		slices.Sort(fqdnTypes)
		snippets = append(snippets, snippet{Desc: fqdn + " (" + strings.Join(fqdnTypes, ", ") + ")", Text: fqdn})
	}
	return newGroup(gcpDNSGroupName, snippets)
}

// generateGCPDNS writes the Cloud DNS records of the projects with dns in their ID or name to dir.
func generateGCPDNS(dir string) error {
	projects, err := listProjects()
	if err != nil {
		return err
	}
	ids := dnsProjects(projects)
	if len(ids) == 0 {
		return fmt.Errorf("no project with %q in its ID or name visible to the gcloud account", gcpDNSProjectMarker)
	}
	zonesByProject, err := concurrentMap(ids, gcpWorkers, listDNSZones)
	if err != nil {
		return err
	}
	var zones []gcpDNSZone
	for _, projectZones := range zonesByProject {
		zones = append(zones, projectZones...)
	}
	recordsByZone, err := concurrentMap(zones, gcpWorkers, listDNSRecords)
	if err != nil {
		return err
	}
	var records []gcpDNSRecord
	for _, zoneRecords := range recordsByZone {
		records = append(records, zoneRecords...)
	}
	return write(dir, gcpDNSFile, dnsRecordGroup(records))
}
