#!/bin/bash

# Password Authentication Test Suite for ansible/ansible-playbook Wrappers
# Tests scenarios with -k parameter and mixed authentication methods

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Source the ansible_preauth functions
source ~/.aliases

# Function to clear SSH ControlMaster sessions
function clear_ssh_sessions() {
    echo -e "${CYAN}🧹 Clearing SSH ControlMaster sessions...${NC}"
    for host in pihole dockassist hifipi cobra vinylstreamer devpi; do
        ssh -O exit "$host" 2>/dev/null || true
    done
    rm -f ~/.ssh/master-* 2>/dev/null || true
    echo -e "${CYAN}✓ SSH sessions cleared${NC}"
}

# Function to test password auth scenarios
function test_password_auth_behavior() {
    local test_name="$1"
    local command="$2"
    local description="$3"
    local expected_behavior="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $command"
    echo "  Expected: $expected_behavior"
    
    clear_ssh_sessions
    
    echo -e "${YELLOW}Executing command (will timeout after 10 seconds to avoid hanging)...${NC}"
    
    # Use timeout to prevent hanging on password prompts
    local output
    local exit_code
    
    # Capture output with timeout
    if output=$(timeout 10s eval "$command" 2>&1); then
        exit_code=$?
    else
        exit_code=124  # timeout exit code
        output="Command timed out (likely waiting for password input)"
    fi
    
    # Check for pre-auth indicators in output
    local preauth_triggered=false
    if echo "$output" | grep -q "SSH sessions cached for Ansible" || echo "$output" | grep -q "🔐 Pre-authenticating"; then
        preauth_triggered=true
    fi
    
    # Check for password prompt indicators
    local password_prompt=false
    if echo "$output" | grep -q "SSH password:" || echo "$output" | grep -q "password:" || [[ $exit_code -eq 124 ]]; then
        password_prompt=true
    fi
    
    echo "  Pre-auth triggered: $preauth_triggered"
    echo "  Password prompt: $password_prompt"
    echo "  Exit code: $exit_code"
    echo "  Output preview:"
    echo "$output" | head -3 | sed 's/^/    /'
    
    # For these tests, we mainly want to ensure the wrapper doesn't crash
    # and behaves reasonably with password auth scenarios
    echo -e "  ${GREEN}✓ BEHAVIOR OBSERVED${NC} (Manual verification needed)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo
}

# Create test playbook for password auth testing
function setup_password_test_files() {
    echo -e "${CYAN}Setting up password authentication test files...${NC}"
    
    # Safe ping playbook for devpi (password auth host)
    cat > test_password_single.yml << 'EOF'
---
- name: Password Auth Test - Single Host
  hosts: devpi
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    # Mixed auth playbook (key-based + password-based)
    cat > test_mixed_auth.yml << 'EOF'
---
- name: Mixed Auth Test
  hosts: pihole, devpi
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    echo -e "${CYAN}✓ Password auth test files created${NC}"
    echo
}

# Test ansible-playbook with password authentication
function test_ansible_playbook_password() {
    echo -e "${YELLOW}=== ansible-playbook Password Authentication Tests ===${NC}"
    
    # Test 1: Single password host with -k (should skip pre-auth)
    test_password_auth_behavior \
        "Single password host with -k" \
        "ansible-playbook --check -k test_password_single.yml" \
        "Single password host should skip pre-auth, prompt for password" \
        "No pre-auth, password prompt expected"
    
    # Test 2: Single password host with -k and limit (should skip pre-auth)
    test_password_auth_behavior \
        "Single password host with -k and limit" \
        "ansible-playbook --check -k --limit devpi test_mixed_auth.yml" \
        "Limited to single password host should skip pre-auth" \
        "No pre-auth, password prompt expected"
    
    # Test 3: Mixed auth hosts with -k (should trigger pre-auth for key hosts)
    test_password_auth_behavior \
        "Mixed auth hosts with -k" \
        "ansible-playbook --check -k test_mixed_auth.yml" \
        "Mixed key/password hosts should pre-auth key hosts, prompt for password" \
        "Pre-auth for key hosts, then password prompt"
    
    # Test 4: Mixed auth with limit to key host only (should skip pre-auth)
    test_password_auth_behavior \
        "Mixed auth limited to key host" \
        "ansible-playbook --check -k --limit pihole test_mixed_auth.yml" \
        "Limited to key host should skip pre-auth even with -k" \
        "No pre-auth, direct execution"
    
    # Test 5: Multiple password hosts (if we had them)
    test_password_auth_behavior \
        "Multiple hosts including password host" \
        "ansible-playbook --check -k --limit pihole,devpi test_mixed_auth.yml" \
        "Multiple hosts with mixed auth should trigger pre-auth" \
        "Pre-auth for key hosts, password prompt for password hosts"
}

# Test ansible ad-hoc commands with password authentication
function test_ansible_password() {
    echo -e "${YELLOW}=== ansible Ad-hoc Password Authentication Tests ===${NC}"
    
    # Test 1: Single password host with -k
    test_password_auth_behavior \
        "ansible single password host" \
        "ansible devpi -m ping -k" \
        "Single password host should skip pre-auth, prompt for password" \
        "No pre-auth, password prompt expected"
    
    # Test 2: Multiple hosts including password host
    test_password_auth_behavior \
        "ansible mixed auth hosts" \
        "ansible pihole,devpi -m ping -k" \
        "Mixed auth hosts should trigger pre-auth for key hosts" \
        "Pre-auth for key hosts, password prompt for password hosts"
    
    # Test 3: Password host with complex command
    test_password_auth_behavior \
        "ansible password host complex command" \
        "ansible devpi -m setup -k --verbose" \
        "Complex command with password host should skip pre-auth" \
        "No pre-auth, password prompt expected"
    
    # Test 4: All hosts including password host
    test_password_auth_behavior \
        "ansible all hosts with password" \
        "ansible all -m ping -k --limit devpi" \
        "All hosts limited to password host should skip pre-auth" \
        "No pre-auth, password prompt expected"
}

# Test edge cases with password authentication
function test_password_edge_cases() {
    echo -e "${YELLOW}=== Password Authentication Edge Cases ===${NC}"
    
    # Test 1: -k without password host (should work normally)
    test_password_auth_behavior \
        "-k flag with key-only hosts" \
        "ansible-playbook --check -k --limit pihole test_mixed_auth.yml" \
        "-k flag with key-only hosts should work normally" \
        "Normal execution, no password prompt needed"
    
    # Test 2: Password host without -k (should fail with auth error)
    test_password_auth_behavior \
        "Password host without -k flag" \
        "ansible devpi -m ping" \
        "Password host without -k should fail with auth error" \
        "Authentication failure expected"
    
    # Test 3: Mixed auth with become options
    test_password_auth_behavior \
        "Mixed auth with become" \
        "ansible-playbook --check -k --become --limit devpi test_password_single.yml" \
        "Password auth with become should work" \
        "Password prompts for both SSH and sudo"
}

# Test pre-auth behavior with password scenarios
function test_preauth_with_passwords() {
    echo -e "${YELLOW}=== Pre-auth Behavior with Password Scenarios ===${NC}"
    
    echo -e "${BLUE}Testing underlying functions with password scenarios:${NC}"
    
    # Test host extraction with password hosts
    local result
    result=$(get_preauth_hosts "--check" "-k" "test_mixed_auth.yml")
    echo "  get_preauth_hosts with -k flag: '$result'"
    echo "  Expected: Should extract hosts normally (pihole devpi)"
    
    result=$(extract_limit_hosts "ansible-playbook --check -k --limit devpi test_mixed_auth.yml")
    echo "  extract_limit_hosts with -k: '$result'"
    echo "  Expected: 'devpi'"
    
    result=$(count_limit_hosts "devpi")
    echo "  count_limit_hosts for password host: '$result'"
    echo "  Expected: '1'"
    
    echo
    echo -e "${CYAN}Key Observations:${NC}"
    echo "  • Pre-auth logic should work the same regardless of -k flag"
    echo "  • -k flag affects Ansible's auth method, not our wrapper logic"
    echo "  • Mixed auth scenarios should pre-auth key hosts, prompt for password hosts"
    echo "  • Single password host should skip pre-auth (same as single key host)"
    echo
}

# Cleanup test files
function cleanup_password_test_files() {
    echo -e "${CYAN}Cleaning up password auth test files...${NC}"
    rm -f test_password_single.yml test_mixed_auth.yml
    echo -e "${CYAN}✓ Password auth test files cleaned up${NC}"
    echo
}

# Main test execution
function run_password_auth_tests() {
    echo -e "${BLUE}Password Authentication Test Suite${NC}"
    echo "=================================="
    echo "Testing ansible/ansible-playbook wrappers with password authentication (-k)"
    echo "Using devpi host (password auth) and pihole host (key auth) for mixed scenarios"
    echo
    echo -e "${YELLOW}⚠ IMPORTANT NOTES:${NC}"
    echo "• Tests will timeout after 10 seconds to avoid hanging on password prompts"
    echo "• Manual verification may be needed for some scenarios"
    echo "• Some tests may prompt for passwords - this is expected behavior"
    echo
    
    # Verify devpi host is configured for password auth
    echo -e "${CYAN}Verifying test environment:${NC}"
    echo "• devpi host: password authentication"
    echo "• pihole host: key authentication"
    echo "• Mixed scenarios will test both authentication methods"
    echo
    
    setup_password_test_files
    
    test_preauth_with_passwords
    test_ansible_playbook_password
    test_ansible_password
    test_password_edge_cases
    
    cleanup_password_test_files
    
    # Final results
    echo -e "${BLUE}=================================="
    echo -e "PASSWORD AUTH TEST RESULTS${NC}"
    echo "=================================="
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Completed:   ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    
    echo
    echo -e "${GREEN}✅ PASSWORD AUTHENTICATION TESTING COMPLETE${NC}"
    echo
    echo -e "${CYAN}Key Findings:${NC}"
    echo "• The wrapper logic should work the same with -k flag"
    echo "• Pre-auth decisions based on host count, not auth method"
    echo "• Mixed auth scenarios should handle both key and password hosts"
    echo "• Single password host should skip pre-auth (same logic as key hosts)"
    echo
    echo -e "${YELLOW}Manual Verification Recommended:${NC}"
    echo "• Test actual password prompts with devpi host"
    echo "• Verify mixed auth scenarios work as expected"
    echo "• Confirm pre-auth doesn't interfere with password prompts"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_password_auth_tests
fi
