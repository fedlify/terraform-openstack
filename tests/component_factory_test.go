package tests

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

type planOutput struct {
	PlannedValues struct {
		Outputs map[string]struct {
			Value any `json:"value"`
		} `json:"outputs"`
	} `json:"planned_values"`
}

func TestManifestComposition(t *testing.T) {
	repoRoot, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to determine working directory: %v", err)
	}

	workdir := filepath.Join(repoRoot, "component_factory_basic")

	terraformCmd(t, workdir, "init", "-backend=false")

	planPath := filepath.Join(workdir, "plan-unit.out")
	terraformCmd(t, workdir, "plan", "-lock=false", "-input=false", "-refresh=false", "-out="+planPath)
	t.Cleanup(func() { _ = os.Remove(planPath) })

	planJSON := terraformCmd(t, workdir, "show", "-json", planPath)

	manifest := extractManifest(t, planJSON)

	computeInstances := mustMap(t, manifest["compute_instances"])
	webInstance := mustMap(t, computeInstances["web"])
	metadata := mustMap(t, webInstance["metadata"])
	if got := mustString(t, metadata["role"]); got != "web" {
		t.Fatalf("expected metadata.role to be 'web', got %q", got)
	}

	networks := mustMap(t, manifest["networks"])
	mainNet := mustMap(t, networks["main"])
	if got := mustBool(t, mainNet["admin_state_up"]); !got {
		t.Fatalf("expected networks.main.admin_state_up to be true")
	}

	volumes := mustMap(t, manifest["volumes"])
	if _, exists := volumes["extra"]; !exists {
		t.Fatalf("expected inline manifest to add 'extra' volume")
	}

	securityGroups := mustMap(t, manifest["security_groups"])
	webGroup := mustMap(t, securityGroups["web"])
	rules := mustMap(t, webGroup["rules"])
	httpsRule := mustMap(t, rules["allow_https"])
	if got := mustNumber(t, httpsRule["port_range_max"]); got != 443 {
		t.Fatalf("expected security_groups.web.rules.allow_https.port_range_max to be 443, got %d", got)
	}
}

func extractManifest(t *testing.T, planJSON []byte) map[string]any {
	t.Helper()

	var plan planOutput
	if err := json.Unmarshal(planJSON, &plan); err != nil {
		t.Fatalf("failed to parse plan json: %v", err)
	}

	manifestOutput, ok := plan.PlannedValues.Outputs["manifest"]
	if !ok {
		t.Fatalf("plan did not produce a 'manifest' output")
	}

	return mustMap(t, manifestOutput.Value)
}

func terraformCmd(t *testing.T, dir string, args ...string) []byte {
	t.Helper()

	fullArgs := append([]string{"-chdir=" + dir}, args...)
	cmd := exec.Command("terraform", fullArgs...)
	cmd.Env = os.Environ()
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("terraform %v failed: %v\n%s", args, err, string(out))
	}

	return out
}

func mustMap(t *testing.T, val any) map[string]any {
	t.Helper()

	m, ok := val.(map[string]any)
	if !ok {
		t.Fatalf("expected map[string]any, got %T", val)
	}
	return m
}

func mustString(t *testing.T, val any) string {
	t.Helper()

	s, ok := val.(string)
	if !ok {
		t.Fatalf("expected string, got %T", val)
	}
	return s
}

func mustBool(t *testing.T, val any) bool {
	t.Helper()

	b, ok := val.(bool)
	if !ok {
		t.Fatalf("expected bool, got %T", val)
	}
	return b
}

func mustNumber(t *testing.T, val any) int {
	t.Helper()

	switch v := val.(type) {
	case float64:
		return int(v)
	case int:
		return v
	default:
		t.Fatalf("expected numeric type, got %T", val)
		return 0
	}
}
