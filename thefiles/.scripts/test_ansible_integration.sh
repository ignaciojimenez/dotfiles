#!/bin/bash

# Unified Ansible Integration Test Suite for ansible_preauth Wrapper
# Tests real ansible/ansible-playbook commands with minimal sample configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test results log
TEST_LOG="/tmp/ansible_preauth_integration_test.log"
echo "Ansible Pre-auth Integration Test Results - $(date)" > "$TEST_LOG"

# Source the ansible_preauth functions
source ~/.ansible_preauth

# Verify wrapper functions are loaded
if ! declare -f ansible >/dev/null || ! declare -f ansible-playbook >/dev/null; then
    echo -e "${RED}Error: ansible wrapper functions not loaded properly${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Ansible wrapper functions loaded${NC}"

# Test directory setup
TEST_DIR="/tmp/ansible_preauth_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create minimal sample configuration files
echo -e "${CYAN}Setting up minimal test environment...${NC}"

# Sample inventory
cat > hosts << 'EOF'
[test_hosts]
dockassist
pihole

[single_host]
pihole

[multi_hosts]
dockassist
pihole

[all:vars]
ansible_user=choco
EOF

# Sample ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
inventory = /Users/choco/Documents/Workspaces/raspberrypi-ansible/hosts
host_key_checking = false
timeout = 5

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPath=~/.ssh/control:%h:%p:%r -o ControlPersist=10m
EOF

# Sample playbook for single host
cat > single_host_playbook.yml << 'EOF'
---
- name: Single host test playbook
  hosts: dockassist
  gather_facts: false
  tasks:
    - name: Test task
      debug:
        msg: "Testing single host"
EOF

# Sample playbook for multiple hosts
cat > multi_host_playbook.yml << 'EOF'
---
- name: Multi host test playbook
  hosts: dockassist,pihole
  gather_facts: false
  tasks:
    - name: Test task
      debug:
        msg: "Testing multiple hosts: {{ inventory_hostname }}"
    - name: Ping test
      ping:
EOF

# Sample playbook for all hosts
cat > all_hosts_playbook.yml << 'EOF'
---
- name: All hosts test playbook
  hosts: all
  gather_facts: false
  tasks:
    - name: Test task
      debug:
        msg: "Testing all hosts"
EOF

echo -e "${GREEN}✓ Test environment created${NC}"
echo

# Enhanced test helper function with comprehensive SSH session management
function test_ansible_command() {
    local test_name="$1"
    local command="$2"
    local expected_preauth="$3"
    local description="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $command"
    echo "  Expected pre-auth: $expected_preauth"
    
    # Comprehensive SSH session cleanup
    echo "  Cleaning SSH sessions..."
    for host in dockassist pihole localhost 127.0.0.1; do
        ssh -O exit "$host" 2>/dev/null || true
    done
    
    # Clear any stale control sockets
    find ~/.ssh -name "control:*" -type s -delete 2>/dev/null || true
    
    # Wait a moment for cleanup to complete
    sleep 0.5
    
    # Capture command output with extended timeout using wrapper functions
    local output
    local exit_code
    # Source the wrapper functions in the subshell to ensure they're available
    output=$(timeout 30s bash -c "source ~/.ansible_preauth && $command" 2>&1 || true)
    exit_code=$?
    
    # Enhanced pre-auth detection with multiple patterns
    local preauth_triggered="false"
    if [[ "$output" == *"Pre-authenticating SSH sessions"* ]] || 
       [[ "$output" == *"🔐 Pre-authenticating"* ]] || 
       [[ "$output" == *"SSH sessions cached"* ]] || 
       [[ "$output" == *"Pre-auth triggered"* ]]; then
        preauth_triggered="true"
    fi
    
    # Additional validation for host counting logic
    local host_count_detected="unknown"
    if [[ "$output" == *"No hosts found"* ]]; then
        host_count_detected="0"
    elif [[ "$output" == *"Single host detected"* ]]; then
        host_count_detected="1"
    elif [[ "$output" == *"Multiple hosts detected"* ]]; then
        host_count_detected="multiple"
    fi
    
    echo "  Actual pre-auth: $preauth_triggered"
    echo "  Host count detected: $host_count_detected"
    echo "  Exit code: $exit_code"
    
    # Log detailed output for debugging
    echo "  Output preview: $(echo "$output" | head -3 | tr '\n' ' ')..."
    
    if [[ "$preauth_triggered" == "$expected_preauth" ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "PASS: $test_name - $description" >> "$TEST_LOG"
        echo "  Output: $output" >> "$TEST_LOG"
    else
        echo -e "  ${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "FAIL: $test_name - Expected preauth=$expected_preauth, got preauth=$preauth_triggered" >> "$TEST_LOG"
        echo "  Command: $command" >> "$TEST_LOG"
        echo "  Output: $output" >> "$TEST_LOG"
        echo "  ---" >> "$TEST_LOG"
    fi
    echo
}

# Test Suite: ansible-playbook wrapper integration
echo -e "${CYAN}=== Testing ansible-playbook Wrapper Integration ===${NC}"

# Basic playbook tests
test_ansible_command "playbook_single_host_limit" "ansible-playbook --check --limit dockassist multi_host_playbook.yml" "false" "Single host limit should skip pre-auth"
test_ansible_command "playbook_multiple_hosts_limit" "ansible-playbook --check --limit dockassist,pihole multi_host_playbook.yml" "true" "Multiple hosts limit should trigger pre-auth"
test_ansible_command "playbook_no_limit_single" "ansible-playbook --check single_host_playbook.yml" "false" "Single host playbook should skip pre-auth"
test_ansible_command "playbook_no_limit_multiple" "ansible-playbook --check multi_host_playbook.yml" "true" "Multiple hosts playbook should trigger pre-auth"
test_ansible_command "playbook_all_hosts" "ansible-playbook --check all_hosts_playbook.yml" "true" "All hosts playbook should trigger pre-auth"

# Advanced limit patterns
test_ansible_command "playbook_limit_pattern" "ansible-playbook --check --limit 'dock*' multi_host_playbook.yml" "false" "Pattern limit single match should skip pre-auth"
test_ansible_command "playbook_limit_negation" "ansible-playbook --check --limit '!dockassist' multi_host_playbook.yml" "false" "Negation limit single result should skip pre-auth"
test_ansible_command "playbook_limit_group" "ansible-playbook --check --limit test_hosts multi_host_playbook.yml" "true" "Group limit multiple hosts should trigger pre-auth"

# Complex argument combinations
test_ansible_command "playbook_complex_args" "ansible-playbook --check --diff --become --limit dockassist --extra-vars 'var=value' single_host_playbook.yml" "false" "Complex args single host should skip pre-auth"
test_ansible_command "playbook_complex_multi" "ansible-playbook --check --diff --become --limit dockassist,pihole --extra-vars 'var=value' multi_host_playbook.yml" "true" "Complex args multiple hosts should trigger pre-auth"

# Test Suite: ansible ad-hoc wrapper integration
echo -e "${CYAN}=== Testing ansible Ad-hoc Wrapper Integration ===${NC}"

# Basic ad-hoc tests
test_ansible_command "ansible_single_host" "ansible dockassist -m ping" "false" "Single host should skip pre-auth"
test_ansible_command "ansible_multiple_hosts" "ansible dockassist,pihole -m ping" "true" "Multiple hosts should trigger pre-auth"
test_ansible_command "ansible_all_hosts" "ansible all -m setup" "true" "All hosts should trigger pre-auth"
test_ansible_command "ansible_limit_single" "ansible all --limit dockassist -m ping" "false" "Single host limit should skip pre-auth"
test_ansible_command "ansible_limit_multiple" "ansible all --limit dockassist,pihole -m ping" "true" "Multiple hosts limit should trigger pre-auth"

# Advanced patterns and modules
test_ansible_command "ansible_pattern_single" "ansible 'dock*' -m ping" "false" "Pattern matching single host should skip pre-auth"
test_ansible_command "ansible_group_multiple" "ansible test_hosts -m setup" "true" "Group targeting multiple hosts should trigger pre-auth"
test_ansible_command "ansible_complex_module" "ansible dockassist -m shell -a 'echo test' --become" "false" "Complex module single host should skip pre-auth"
test_ansible_command "ansible_complex_multi_module" "ansible dockassist,pihole -m shell -a 'echo test' --become" "true" "Complex module multiple hosts should trigger pre-auth"

# Edge cases and special scenarios
test_ansible_command "ansible_limit_spaces" "ansible all --limit 'dockassist, pihole' -m ping" "true" "Limit with spaces should trigger pre-auth for multiple hosts"
test_ansible_command "ansible_limit_quoted" "ansible all --limit \"dockassist,pihole\" -m ping" "true" "Quoted limit multiple hosts should trigger pre-auth"

# Test Suite: Password Authentication Scenarios
echo -e "${CYAN}=== Testing Password Authentication Scenarios ===${NC}"

test_ansible_command "password_auth_single" "ansible-playbook --check -k --limit dockassist single_host_playbook.yml" "false" "Password auth single host should skip pre-auth"
test_ansible_command "password_auth_multiple" "ansible-playbook --check -k --limit dockassist,pihole multi_host_playbook.yml" "true" "Password auth multiple hosts should trigger pre-auth"
test_ansible_command "password_auth_ansible_single" "ansible dockassist -m ping -k" "false" "Password auth ansible single host should skip pre-auth"
test_ansible_command "password_auth_ansible_multi" "ansible dockassist,pihole -m ping -k" "true" "Password auth ansible multiple hosts should trigger pre-auth"

# Test Suite: Edge Cases and Error Handling
echo -e "${CYAN}=== Testing Edge Cases and Error Handling ===${NC}"

test_ansible_command "empty_limit" "ansible all --limit '' -m ping" "true" "Empty limit should default to all hosts and trigger pre-auth"
test_ansible_command "nonexistent_host" "ansible nonexistent -m ping" "false" "Nonexistent single host should skip pre-auth"
test_ansible_command "mixed_existing_nonexistent" "ansible dockassist,nonexistent -m ping" "true" "Mixed existing/nonexistent hosts should trigger pre-auth"
test_ansible_command "playbook_complex_args" "ansible-playbook --check --diff --limit dockassist --become single_host_playbook.yml" "false" "Complex single host args should skip pre-auth"
test_ansible_command "complex_ansible_args" "ansible dockassist -m setup -a gather_subset=min --become" "false" "Complex single host ansible should skip pre-auth"

# Test Suite: Inventory and Configuration Tests
echo -e "${CYAN}=== Testing Inventory and Configuration Scenarios ===${NC}"

test_ansible_command "inventory_override" "ansible-playbook --check -i hosts --limit dockassist,pihole multi_host_playbook.yml" "true" "Explicit inventory multiple hosts should trigger pre-auth"
test_ansible_command "vault_password" "ansible-playbook --check --ask-vault-pass --limit dockassist single_host_playbook.yml" "false" "Vault password single host should skip pre-auth"
test_ansible_command "become_password" "ansible-playbook --check --ask-become-pass --limit dockassist,pihole multi_host_playbook.yml" "true" "Become password multiple hosts should trigger pre-auth"


# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"

# Final results
echo -e "${CYAN}=== Integration Test Results Summary ===${NC}"
echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

# Calculate success rate
if [[ $TOTAL_TESTS -gt 0 ]]; then
    success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success Rate: ${BLUE}${success_rate}%${NC}"
fi

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 All integration tests passed!${NC}"
    echo "SUCCESS: All $TOTAL_TESTS integration tests passed" >> "$TEST_LOG"
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS integration test(s) failed${NC}"
    echo "FAILURE: $FAILED_TESTS out of $TOTAL_TESTS integration tests failed" >> "$TEST_LOG"
    exit 1
fi

echo -e "\n${CYAN}Integration test log saved to: $TEST_LOG${NC}"
echo -e "${YELLOW}View detailed results: cat $TEST_LOG${NC}"
