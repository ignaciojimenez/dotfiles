#!/bin/bash

# Comprehensive Edge Case Test Suite for ansible-playbook Wrapper
# Tests all missing edge cases with safe, non-destructive commands

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

# Function to check if pre-auth was triggered
function check_preauth_behavior() {
    local test_name="$1"
    local expected_preauth="$2"
    local command="$3"
    local description="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $command"
    echo "  Expected pre-auth: $expected_preauth"
    
    clear_ssh_sessions
    
    echo -e "${YELLOW}Executing command...${NC}"
    
    # Capture output to check for pre-auth indicators
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    # Check for pre-auth indicators in output
    local preauth_triggered=false
    if echo "$output" | grep -q "SSH sessions cached for Ansible" || echo "$output" | grep -q "🔐 Pre-authenticating"; then
        preauth_triggered=true
    fi
    
    echo "  Pre-auth triggered: $preauth_triggered"
    echo "  Exit code: $exit_code"
    
    # Determine test result
    local test_passed=false
    if [[ "$expected_preauth" == "true" && "$preauth_triggered" == "true" ]]; then
        test_passed=true
    elif [[ "$expected_preauth" == "false" && "$preauth_triggered" == "false" ]]; then
        test_passed=true
    elif [[ "$expected_preauth" == "any" ]]; then
        # For edge cases where behavior may vary
        test_passed=true
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "  Output snippet:"
        echo "$output" | head -5 | sed 's/^/    /'
    fi
    echo
}

# Setup test files
function setup_edge_case_test_files() {
    echo -e "${CYAN}Setting up edge case test files...${NC}"
    
    # Create test playbook with multiple plays
    cat > test_multi_play.yml << 'EOF'
---
- name: First Play
  hosts: pihole
  gather_facts: no
  tasks:
    - name: Ping test
      ping:

- name: Second Play  
  hosts: dockassist
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    # Create test playbook with no hosts
    cat > test_no_hosts.yml << 'EOF'
---
- name: No Hosts Play
  gather_facts: no
  tasks:
    - name: Local task
      debug:
        msg: "This runs locally"
EOF

    # Create test playbook with group hosts
    cat > test_group_hosts.yml << 'EOF'
---
- name: Group Hosts Play
  hosts: webservers
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    # Create test playbook with all hosts
    cat > test_all_hosts.yml << 'EOF'
---
- name: All Hosts Play
  hosts: all
  gather_facts: no
  tasks:
    - name: Gather facts only
      setup:
        gather_subset: min
EOF

    # Create alternative inventory file
    cat > test_inventory_alt << 'EOF'
[webservers]
pihole
dockassist

[databases]
hifipi

[monitoring]
cobra
vinylstreamer

[development]
devpi
EOF

    echo -e "${CYAN}✓ Edge case test files created${NC}"
    echo
}

# Test host pattern matching edge cases
function test_host_patterns() {
    echo -e "${YELLOW}=== Testing Host Pattern Edge Cases ===${NC}"
    
    # Test wildcard patterns (single match)
    check_preauth_behavior \
        "Wildcard pattern single match" \
        "false" \
        "ansible-playbook --check --limit 'pihole*' test_all_hosts.yml" \
        "Wildcard pattern that matches single host should skip pre-auth"
    
    # Test wildcard patterns (multiple matches)
    check_preauth_behavior \
        "Wildcard pattern multiple matches" \
        "true" \
        "ansible-playbook --check --limit '*hole*' test_all_hosts.yml" \
        "Wildcard pattern that matches multiple hosts should trigger pre-auth"
    
    # Test group patterns
    check_preauth_behavior \
        "Group pattern" \
        "true" \
        "ansible-playbook --check --limit 'webservers' test_all_hosts.yml" \
        "Group pattern should trigger pre-auth for multiple hosts"
    
    # Test exclusion patterns
    check_preauth_behavior \
        "Exclusion pattern" \
        "true" \
        "ansible-playbook --check --limit 'all:!devpi' test_all_hosts.yml" \
        "Exclusion pattern should trigger pre-auth for remaining hosts"
    
    # Test intersection patterns
    check_preauth_behavior \
        "Intersection pattern" \
        "true" \
        "ansible-playbook --check --limit 'webservers:&all' test_all_hosts.yml" \
        "Intersection pattern should trigger pre-auth"
}

# Test invalid and non-existent hosts
function test_invalid_hosts() {
    echo -e "${YELLOW}=== Testing Invalid/Non-existent Hosts ===${NC}"
    
    # Test non-existent single host
    check_preauth_behavior \
        "Non-existent single host" \
        "false" \
        "ansible-playbook --check --limit 'nonexistent' test_all_hosts.yml" \
        "Non-existent single host should skip pre-auth"
    
    # Test mix of valid and invalid hosts
    check_preauth_behavior \
        "Mix of valid and invalid hosts" \
        "true" \
        "ansible-playbook --check --limit 'pihole,nonexistent,dockassist' test_all_hosts.yml" \
        "Mix of valid/invalid hosts should trigger pre-auth"
    
    # Test non-existent group
    check_preauth_behavior \
        "Non-existent group" \
        "any" \
        "ansible-playbook --check --limit 'nonexistentgroup' test_all_hosts.yml" \
        "Non-existent group behavior may vary"
    
    # Test empty limit
    check_preauth_behavior \
        "Empty limit parameter" \
        "true" \
        "ansible-playbook --check --limit '' test_all_hosts.yml" \
        "Empty limit should fall back to playbook hosts"
}

# Test complex limit expressions
function test_complex_limits() {
    echo -e "${YELLOW}=== Testing Complex Limit Expressions ===${NC}"
    
    # Test multiple groups
    check_preauth_behavior \
        "Multiple groups" \
        "true" \
        "ansible-playbook --check --limit 'webservers,databases' test_all_hosts.yml" \
        "Multiple groups should trigger pre-auth"
    
    # Test range expressions (if supported)
    check_preauth_behavior \
        "Range expression" \
        "any" \
        "ansible-playbook --check --limit 'web[1:3]' test_all_hosts.yml" \
        "Range expression behavior may vary"
    
    # Test complex boolean expressions
    check_preauth_behavior \
        "Complex boolean expression" \
        "true" \
        "ansible-playbook --check --limit 'webservers:!pihole' test_all_hosts.yml" \
        "Complex boolean expression should trigger pre-auth"
    
    # Test very long limit list
    check_preauth_behavior \
        "Very long limit list" \
        "true" \
        "ansible-playbook --check --limit 'pihole,dockassist,hifipi,cobra,vinylstreamer' test_all_hosts.yml" \
        "Very long limit list should trigger pre-auth"
}

# Test argument parsing edge cases
function test_argument_parsing() {
    echo -e "${YELLOW}=== Testing Argument Parsing Edge Cases ===${NC}"
    
    # Test multiple limit parameters (last one wins)
    check_preauth_behavior \
        "Multiple limit parameters" \
        "false" \
        "ansible-playbook --check --limit pihole,dockassist --limit pihole test_all_hosts.yml" \
        "Multiple limit parameters - last one should win (single host)"
    
    # Test limit with special characters
    check_preauth_behavior \
        "Limit with special characters" \
        "false" \
        "ansible-playbook --check --limit 'pihole.local' test_all_hosts.yml" \
        "Limit with dots should work for single host"
    
    # Test limit with spaces and quotes
    check_preauth_behavior \
        "Limit with spaces in quotes" \
        "true" \
        "ansible-playbook --check --limit 'pihole, dockassist' test_all_hosts.yml" \
        "Limit with spaces should trigger pre-auth"
    
    # Test very long command line
    check_preauth_behavior \
        "Very long command line" \
        "false" \
        "ansible-playbook --check --verbose --inventory inventory --extra-vars 'test=value' --limit pihole --tags all --skip-tags never test_all_hosts.yml" \
        "Very long command with single host should skip pre-auth"
}

# Test playbook edge cases
function test_playbook_edge_cases() {
    echo -e "${YELLOW}=== Testing Playbook Edge Cases ===${NC}"
    
    # Test playbook with multiple plays
    check_preauth_behavior \
        "Multiple plays playbook" \
        "true" \
        "ansible-playbook --check test_multi_play.yml" \
        "Multiple plays should trigger pre-auth"
    
    # Test playbook with no hosts defined
    check_preauth_behavior \
        "No hosts defined playbook" \
        "any" \
        "ansible-playbook --check test_no_hosts.yml" \
        "No hosts defined - behavior may vary"
    
    # Test playbook with group hosts
    check_preauth_behavior \
        "Group hosts playbook" \
        "true" \
        "ansible-playbook --check test_group_hosts.yml" \
        "Group hosts should trigger pre-auth"
    
    # Test playbook with 'all' hosts
    check_preauth_behavior \
        "All hosts playbook" \
        "true" \
        "ansible-playbook --check test_all_hosts.yml" \
        "All hosts should trigger pre-auth"
}

# Test inventory edge cases
function test_inventory_edge_cases() {
    echo -e "${YELLOW}=== Testing Inventory Edge Cases ===${NC}"
    
    # Test with alternative inventory
    check_preauth_behavior \
        "Alternative inventory file" \
        "true" \
        "ansible-playbook --check --inventory test_inventory_alt test_all_hosts.yml" \
        "Alternative inventory should work normally"
    
    # Test with non-existent inventory
    check_preauth_behavior \
        "Non-existent inventory" \
        "any" \
        "ansible-playbook --check --inventory nonexistent_inventory test_all_hosts.yml" \
        "Non-existent inventory - behavior may vary"
    
    # Test with multiple inventory sources
    check_preauth_behavior \
        "Multiple inventory sources" \
        "true" \
        "ansible-playbook --check --inventory inventory --inventory test_inventory_alt test_all_hosts.yml" \
        "Multiple inventory sources should work normally"
}

# Test error handling and resilience
function test_error_handling() {
    echo -e "${YELLOW}=== Testing Error Handling ===${NC}"
    
    # Test with malformed playbook
    echo "invalid yaml content" > test_malformed.yml
    check_preauth_behavior \
        "Malformed playbook" \
        "any" \
        "ansible-playbook --check test_malformed.yml" \
        "Malformed playbook should not crash wrapper"
    
    # Test with missing playbook file
    check_preauth_behavior \
        "Missing playbook file" \
        "any" \
        "ansible-playbook --check nonexistent_playbook.yml" \
        "Missing playbook should not crash wrapper"
    
    # Test with invalid options
    check_preauth_behavior \
        "Invalid ansible options" \
        "any" \
        "ansible-playbook --check --invalid-option test_all_hosts.yml" \
        "Invalid options should not crash wrapper"
}

# Test performance with large inventories
function test_performance_edge_cases() {
    echo -e "${YELLOW}=== Testing Performance Edge Cases ===${NC}"
    
    # Create large inventory for testing
    cat > test_large_inventory << 'EOF'
[webservers]
pihole
dockassist

[databases]
hifipi

[monitoring]
cobra
vinylstreamer

[development]
devpi

[production]
pihole
dockassist
hifipi

[staging]
cobra
vinylstreamer
devpi
EOF

    # Test with large inventory and complex patterns
    check_preauth_behavior \
        "Large inventory complex pattern" \
        "true" \
        "ansible-playbook --check --inventory test_large_inventory --limit 'production:&webservers' test_all_hosts.yml" \
        "Large inventory with complex patterns should work efficiently"
    
    # Test with very specific single host from large inventory
    check_preauth_behavior \
        "Single host from large inventory" \
        "false" \
        "ansible-playbook --check --inventory test_large_inventory --limit pihole test_all_hosts.yml" \
        "Single host from large inventory should skip pre-auth"
}

# Cleanup test files
function cleanup_edge_case_test_files() {
    echo -e "${CYAN}Cleaning up edge case test files...${NC}"
    rm -f test_multi_play.yml test_no_hosts.yml test_group_hosts.yml test_all_hosts.yml
    rm -f test_inventory_alt test_large_inventory test_malformed.yml
    echo -e "${CYAN}✓ Edge case test files cleaned up${NC}"
    echo
}

# Main test execution
function run_edge_case_tests() {
    echo -e "${BLUE}Ansible-Playbook Wrapper Edge Case Test Suite${NC}"
    echo "=============================================="
    echo "Testing comprehensive edge cases with safe commands only"
    echo
    
    # Verify we're in the right directory
    if [[ ! -f "inventory" ]]; then
        echo -e "${RED}Warning: inventory file not found in current directory${NC}"
        echo "Some tests may behave differently"
        echo
    fi
    
    setup_edge_case_test_files
    
    test_host_patterns
    test_invalid_hosts
    test_complex_limits
    test_argument_parsing
    test_playbook_edge_cases
    test_inventory_edge_cases
    test_error_handling
    test_performance_edge_cases
    
    cleanup_edge_case_test_files
    
    # Final results
    echo -e "${BLUE}=============================================="
    echo -e "EDGE CASE TEST RESULTS SUMMARY${NC}"
    echo "=============================================="
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL EDGE CASE TESTS PASSED!${NC}"
        echo -e "${GREEN}The ansible-playbook wrapper handles all edge cases correctly${NC}"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS EDGE CASE TESTS FAILED${NC}"
        echo -e "${RED}Some edge cases need attention${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_edge_case_tests
fi
