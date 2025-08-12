#!/bin/bash

# Comprehensive Integration Test Suite for ansible-playbook Wrapper
# Tests all scenarios with deploy_enhanced_speed_monitor.yml and pihole/dockassist hosts

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

# Source the ansible_preauth functions
source ~/.aliases

# Function to clear SSH ControlMaster sessions
function clear_ssh_sessions() {
    echo -e "${CYAN}🧹 Clearing SSH ControlMaster sessions...${NC}"
    
    # Kill any existing ControlMaster sessions
    for host in pihole dockassist; do
        ssh -O exit "$host" 2>/dev/null || true
    done
    
    # Remove any stale control sockets
    rm -f ~/.ssh/master-* 2>/dev/null || true
    
    echo -e "${CYAN}✓ SSH sessions cleared${NC}"
    echo
}

# Function to check if pre-auth was triggered
function check_preauth_triggered() {
    local test_name="$1"
    local expected_preauth="$2"
    local command="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "  Command: $command"
    echo "  Expected pre-auth: $expected_preauth"
    
    # Clear sessions before test
    clear_ssh_sessions
    
    echo -e "${YELLOW}Executing command (--check mode to avoid actual changes)...${NC}"
    
    # Capture output to check for pre-auth indicators
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    # Check for pre-auth indicators in output
    local preauth_triggered=false
    if echo "$output" | grep -q "SSH sessions cached for Ansible" || echo "$output" | grep -q "Connecting to"; then
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
    fi
    
    if [[ "$test_passed" == "true" ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "  Output snippet:"
        echo "$output" | head -10 | sed 's/^/    /'
    fi
    echo
}

# Function to test a command and show its behavior
function test_command_behavior() {
    local test_name="$1"
    local command="$2"
    local description="$3"
    
    echo -e "${BLUE}Behavior Test: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $command"
    
    # Clear sessions before test
    clear_ssh_sessions
    
    echo -e "${YELLOW}Executing command...${NC}"
    
    # Execute and capture output
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    echo "  Exit code: $exit_code"
    echo "  Output preview:"
    echo "$output" | head -5 | sed 's/^/    /'
    echo
}

# Test scenarios for ansible-playbook wrapper
function test_ansible_playbook_scenarios() {
    echo -e "${YELLOW}=== Testing ansible-playbook Wrapper Scenarios ===${NC}"
    echo "Using deploy_enhanced_speed_monitor.yml with hosts: pihole, dockassist"
    echo
    
    # Scenario 1: No limit - should use playbook hosts (multi-host, should pre-auth)
    check_preauth_triggered \
        "No limit parameter (playbook hosts)" \
        "true" \
        "ansible-playbook --check deploy_enhanced_speed_monitor.yml"
    
    # Scenario 2: Limit to single host - should skip pre-auth
    check_preauth_triggered \
        "Limit to single host (pihole)" \
        "false" \
        "ansible-playbook --check --limit pihole deploy_enhanced_speed_monitor.yml"
    
    # Scenario 3: Limit to single host - should skip pre-auth
    check_preauth_triggered \
        "Limit to single host (dockassist)" \
        "false" \
        "ansible-playbook --check --limit dockassist deploy_enhanced_speed_monitor.yml"
    
    # Scenario 4: Limit to multiple hosts - should pre-auth
    check_preauth_triggered \
        "Limit to multiple hosts (both)" \
        "true" \
        "ansible-playbook --check --limit pihole,dockassist deploy_enhanced_speed_monitor.yml"
    
    # Scenario 5: -l format single host - should skip pre-auth
    check_preauth_triggered \
        "-l format single host" \
        "false" \
        "ansible-playbook --check -l pihole deploy_enhanced_speed_monitor.yml"
    
    # Scenario 6: -l format multiple hosts - should pre-auth
    check_preauth_triggered \
        "-l format multiple hosts" \
        "true" \
        "ansible-playbook --check -l pihole,dockassist deploy_enhanced_speed_monitor.yml"
    
    # Scenario 7: --limit= format single host - should skip pre-auth
    check_preauth_triggered \
        "--limit= format single host" \
        "false" \
        "ansible-playbook --check --limit=pihole deploy_enhanced_speed_monitor.yml"
    
    # Scenario 8: --limit= format multiple hosts - should pre-auth
    check_preauth_triggered \
        "--limit= format multiple hosts" \
        "true" \
        "ansible-playbook --check --limit=pihole,dockassist deploy_enhanced_speed_monitor.yml"
    
    # Scenario 9: -l= format single host - should skip pre-auth
    check_preauth_triggered \
        "-l= format single host" \
        "false" \
        "ansible-playbook --check -l=dockassist deploy_enhanced_speed_monitor.yml"
    
    # Scenario 10: -l= format multiple hosts - should pre-auth
    check_preauth_triggered \
        "-l= format multiple hosts" \
        "true" \
        "ansible-playbook --check -l=pihole,dockassist deploy_enhanced_speed_monitor.yml"
}

# Test edge cases and complex scenarios
function test_edge_cases() {
    echo -e "${YELLOW}=== Testing Edge Cases ===${NC}"
    
    # Test with additional options
    check_preauth_triggered \
        "Complex command with multiple options (single host)" \
        "false" \
        "ansible-playbook --check --verbose --limit pihole --inventory inventory deploy_enhanced_speed_monitor.yml"
    
    # Test with additional options and multiple hosts
    check_preauth_triggered \
        "Complex command with multiple options (multi host)" \
        "true" \
        "ansible-playbook --check --verbose --limit pihole,dockassist --inventory inventory deploy_enhanced_speed_monitor.yml"
    
    # Test with spaces in limit (if supported)
    check_preauth_triggered \
        "Limit with spaces (single host)" \
        "false" \
        "ansible-playbook --check --limit 'pihole' deploy_enhanced_speed_monitor.yml"
}

# Test behavior demonstrations (informational)
function test_behavior_demonstrations() {
    echo -e "${YELLOW}=== Behavior Demonstrations ===${NC}"
    
    test_command_behavior \
        "Dry run - no limit" \
        "ansible-playbook --check deploy_enhanced_speed_monitor.yml" \
        "Show behavior when no limit is specified (should target playbook hosts)"
    
    test_command_behavior \
        "Dry run - single host limit" \
        "ansible-playbook --check --limit pihole deploy_enhanced_speed_monitor.yml" \
        "Show behavior when limiting to single host (should skip pre-auth)"
    
    test_command_behavior \
        "Dry run - multi host limit" \
        "ansible-playbook --check --limit pihole,dockassist deploy_enhanced_speed_monitor.yml" \
        "Show behavior when limiting to multiple hosts (should pre-auth)"
}

# Test the underlying functions directly
function test_underlying_functions() {
    echo -e "${YELLOW}=== Testing Underlying Functions with Real Playbook ===${NC}"
    
    # Test get_preauth_hosts with the real playbook
    echo -e "${BLUE}Direct function test: get_preauth_hosts${NC}"
    
    local result
    result=$(get_preauth_hosts "--check" "deploy_enhanced_speed_monitor.yml")
    echo "  get_preauth_hosts result: '$result'"
    echo "  Expected: 'pihole dockassist' (from playbook)"
    
    if [[ "$result" == *"pihole"* && "$result" == *"dockassist"* ]]; then
        echo -e "  ${GREEN}✓ Correctly extracted playbook hosts${NC}"
    else
        echo -e "  ${RED}✗ Failed to extract correct playbook hosts${NC}"
    fi
    echo
    
    # Test with limit parameter
    result=$(get_preauth_hosts "--check" "--limit" "pihole" "deploy_enhanced_speed_monitor.yml")
    echo "  get_preauth_hosts with limit result: '$result'"
    echo "  Expected: 'pihole' (from limit parameter)"
    
    if [[ "$result" == "pihole" ]]; then
        echo -e "  ${GREEN}✓ Correctly used limit parameter${NC}"
    else
        echo -e "  ${RED}✗ Failed to use limit parameter correctly${NC}"
    fi
    echo
    
    # Test count_limit_hosts
    local count
    count=$(count_limit_hosts "pihole")
    echo "  count_limit_hosts('pihole'): $count (expected: 1)"
    
    count=$(count_limit_hosts "pihole,dockassist")
    echo "  count_limit_hosts('pihole,dockassist'): $count (expected: 2)"
    echo
}

# Main test execution
function run_integration_tests() {
    echo -e "${BLUE}Ansible-Playbook Wrapper Integration Test Suite${NC}"
    echo "=============================================="
    echo "Testing with deploy_enhanced_speed_monitor.yml"
    echo "Target hosts: pihole, dockassist"
    echo
    
    # Verify we're in the right directory
    if [[ ! -f "deploy_enhanced_speed_monitor.yml" ]]; then
        echo -e "${RED}Error: deploy_enhanced_speed_monitor.yml not found in current directory${NC}"
        echo "Please run this script from the raspberrypi-ansible directory"
        exit 1
    fi
    
    # Show the playbook hosts for reference
    echo -e "${CYAN}Playbook hosts configuration:${NC}"
    grep -A 2 "hosts:" deploy_enhanced_speed_monitor.yml | sed 's/^/  /'
    echo
    
    test_underlying_functions
    test_ansible_playbook_scenarios
    test_edge_cases
    test_behavior_demonstrations
    
    # Final results
    echo -e "${BLUE}=============================================="
    echo -e "INTEGRATION TEST RESULTS SUMMARY${NC}"
    echo "=============================================="
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL INTEGRATION TESTS PASSED!${NC}"
        echo -e "${GREEN}The ansible-playbook wrapper is working correctly${NC}"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS INTEGRATION TESTS FAILED${NC}"
        echo -e "${RED}The ansible-playbook wrapper needs attention${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
fi
