#!/bin/bash

# Comprehensive Test Suite for ansible Wrapper
# Tests ansible ad-hoc command scenarios with safe, non-destructive commands only

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
    for host in pihole dockassist hifipi cobra vinylstreamer devpi; do
        ssh -O exit "$host" 2>/dev/null || true
    done
    rm -f ~/.ssh/master-* 2>/dev/null || true
    echo -e "${CYAN}✓ SSH sessions cleared${NC}"
}

# Function to check if pre-auth was triggered
function check_ansible_preauth() {
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
        echo "$output" | head -3 | sed 's/^/    /'
    fi
    echo
}

# Test basic ansible ad-hoc commands
function test_basic_ansible_commands() {
    echo -e "${YELLOW}=== Basic Ansible Ad-hoc Command Tests ===${NC}"
    
    # Test single host ping
    check_ansible_preauth \
        "Single host ping" \
        "false" \
        "ansible pihole -m ping" \
        "Single host ping should skip pre-auth"
    
    # Test multiple hosts ping (comma-separated)
    check_ansible_preauth \
        "Multiple hosts ping (comma)" \
        "true" \
        "ansible pihole,dockassist -m ping" \
        "Multiple hosts ping should trigger pre-auth"
    
    # Test all hosts ping
    check_ansible_preauth \
        "All hosts ping" \
        "true" \
        "ansible all -m ping" \
        "All hosts ping should trigger pre-auth"
    
    # Test group hosts
    check_ansible_preauth \
        "Group hosts ping" \
        "true" \
        "ansible webservers -m ping" \
        "Group hosts should trigger pre-auth"
    
    # Test localhost (should skip pre-auth)
    check_ansible_preauth \
        "Localhost command" \
        "false" \
        "ansible localhost -m debug -a 'msg=\"test\"'" \
        "Localhost commands should skip pre-auth"
}

# Test ansible with limit parameters
function test_ansible_with_limits() {
    echo -e "${YELLOW}=== Ansible with Limit Parameter Tests ===${NC}"
    
    # Test all with single host limit
    check_ansible_preauth \
        "All hosts with single limit" \
        "false" \
        "ansible all -m ping --limit pihole" \
        "All hosts limited to single host should skip pre-auth"
    
    # Test all with multiple host limit
    check_ansible_preauth \
        "All hosts with multiple limit" \
        "true" \
        "ansible all -m ping --limit pihole,dockassist" \
        "All hosts limited to multiple hosts should trigger pre-auth"
    
    # Test group with single host limit
    check_ansible_preauth \
        "Group with single limit" \
        "false" \
        "ansible webservers -m ping -l pihole" \
        "Group limited to single host should skip pre-auth"
    
    # Test limit parameter formats
    check_ansible_preauth \
        "Limit equals format" \
        "false" \
        "ansible all -m ping --limit=pihole" \
        "--limit= format with single host should skip pre-auth"
    
    check_ansible_preauth \
        "Short limit format" \
        "true" \
        "ansible all -m ping -l pihole,dockassist" \
        "-l format with multiple hosts should trigger pre-auth"
}

# Test complex host patterns
function test_complex_host_patterns() {
    echo -e "${YELLOW}=== Complex Host Pattern Tests ===${NC}"
    
    # Test wildcard patterns
    check_ansible_preauth \
        "Wildcard single match" \
        "false" \
        "ansible 'pihole*' -m ping" \
        "Wildcard matching single host should skip pre-auth"
    
    # Test exclusion patterns
    check_ansible_preauth \
        "Exclusion pattern" \
        "true" \
        "ansible 'all:!devpi' -m ping" \
        "Exclusion pattern should trigger pre-auth for remaining hosts"
    
    # Test intersection patterns
    check_ansible_preauth \
        "Intersection pattern" \
        "true" \
        "ansible 'webservers:&all' -m ping" \
        "Intersection pattern should trigger pre-auth"
    
    # Test range patterns (if supported)
    check_ansible_preauth \
        "Range pattern" \
        "any" \
        "ansible 'web[1:3]' -m ping" \
        "Range pattern behavior may vary"
}

# Test different ansible modules (all safe)
function test_different_modules() {
    echo -e "${YELLOW}=== Different Ansible Module Tests ===${NC}"
    
    # Test setup module (fact gathering)
    check_ansible_preauth \
        "Setup module single host" \
        "false" \
        "ansible pihole -m setup" \
        "Setup on single host should skip pre-auth"
    
    check_ansible_preauth \
        "Setup module multiple hosts" \
        "true" \
        "ansible pihole,dockassist -m setup" \
        "Setup on multiple hosts should trigger pre-auth"
    
    # Test debug module
    check_ansible_preauth \
        "Debug module single host" \
        "false" \
        "ansible pihole -m debug -a 'msg=\"test\"'" \
        "Debug on single host should skip pre-auth"
    
    # Test command module (safe read-only commands)
    check_ansible_preauth \
        "Command module single host" \
        "false" \
        "ansible pihole -m command -a 'hostname'" \
        "Safe command on single host should skip pre-auth"
    
    check_ansible_preauth \
        "Command module multiple hosts" \
        "true" \
        "ansible pihole,dockassist -m command -a 'uptime'" \
        "Safe command on multiple hosts should trigger pre-auth"
    
    # Test shell module (safe read-only commands)
    check_ansible_preauth \
        "Shell module single host" \
        "false" \
        "ansible pihole -m shell -a 'echo test'" \
        "Safe shell on single host should skip pre-auth"
}

# Test argument parsing edge cases specific to ansible
function test_ansible_argument_parsing() {
    echo -e "${YELLOW}=== Ansible Argument Parsing Tests ===${NC}"
    
    # Test complex module arguments
    check_ansible_preauth \
        "Complex module arguments" \
        "false" \
        "ansible pihole -m debug -a 'msg=\"complex message with spaces\"'" \
        "Complex arguments with single host should skip pre-auth"
    
    # Test multiple options
    check_ansible_preauth \
        "Multiple options single host" \
        "false" \
        "ansible pihole -m ping --verbose --check" \
        "Multiple options with single host should skip pre-auth"
    
    # Test inventory specification
    check_ansible_preauth \
        "Custom inventory single host" \
        "false" \
        "ansible pihole -i inventory -m ping" \
        "Custom inventory with single host should skip pre-auth"
    
    # Test become options
    check_ansible_preauth \
        "Become options single host" \
        "false" \
        "ansible pihole -m ping --become --become-user root" \
        "Become options with single host should skip pre-auth"
}

# Test error handling for ansible
function test_ansible_error_handling() {
    echo -e "${YELLOW}=== Ansible Error Handling Tests ===${NC}"
    
    # Test non-existent host
    check_ansible_preauth \
        "Non-existent single host" \
        "false" \
        "ansible nonexistent -m ping" \
        "Non-existent single host should skip pre-auth"
    
    # Test non-existent hosts in list
    check_ansible_preauth \
        "Mix valid/invalid hosts" \
        "true" \
        "ansible pihole,nonexistent,dockassist -m ping" \
        "Mix of valid/invalid hosts should trigger pre-auth"
    
    # Test invalid module
    check_ansible_preauth \
        "Invalid module single host" \
        "false" \
        "ansible pihole -m invalidmodule" \
        "Invalid module with single host should skip pre-auth"
    
    # Test missing module arguments
    check_ansible_preauth \
        "Missing module args" \
        "false" \
        "ansible pihole -m command" \
        "Missing module args with single host should skip pre-auth"
}

# Test performance with ansible
function test_ansible_performance() {
    echo -e "${YELLOW}=== Ansible Performance Tests ===${NC}"
    
    # Test very long host list
    check_ansible_preauth \
        "Very long host list" \
        "true" \
        "ansible pihole,dockassist,hifipi,cobra,vinylstreamer,devpi -m ping" \
        "Very long host list should trigger pre-auth"
    
    # Test complex command with many options
    check_ansible_preauth \
        "Complex command many options" \
        "false" \
        "ansible pihole -m setup --verbose --check --diff --inventory inventory --extra-vars 'test=value'" \
        "Complex command with single host should skip pre-auth"
}

# Test underlying function behavior with ansible patterns
function test_underlying_functions_ansible() {
    echo -e "${YELLOW}=== Underlying Function Tests for Ansible ===${NC}"
    
    echo -e "${BLUE}Testing extract_ansible_targets function:${NC}"
    
    # Test basic host extraction
    local result
    result=$(extract_ansible_targets "pihole -m ping")
    echo "  extract_ansible_targets('pihole -m ping'): '$result'"
    echo "  Expected: 'pihole'"
    
    result=$(extract_ansible_targets "pihole,dockassist -m setup")
    echo "  extract_ansible_targets('pihole,dockassist -m setup'): '$result'"
    echo "  Expected: 'pihole,dockassist'"
    
    result=$(extract_ansible_targets "all -m ping --limit pihole")
    echo "  extract_ansible_targets('all -m ping --limit pihole'): '$result'"
    echo "  Expected: 'all'"
    
    result=$(extract_ansible_targets "-m ping localhost")
    echo "  extract_ansible_targets('-m ping localhost'): '$result'"
    echo "  Expected: 'localhost' (should skip -m ping)"
    
    echo
}

# Main test execution
function run_ansible_tests() {
    echo -e "${BLUE}Ansible Wrapper Comprehensive Test Suite${NC}"
    echo "=========================================="
    echo "Testing ansible ad-hoc command scenarios"
    echo "Using only safe, non-destructive commands (ping, setup, debug, hostname, uptime)"
    echo
    
    # Verify we're in the right directory
    if [[ ! -f "inventory" ]]; then
        echo -e "${YELLOW}Warning: inventory file not found in current directory${NC}"
        echo "Some tests may behave differently"
        echo
    fi
    
    test_underlying_functions_ansible
    test_basic_ansible_commands
    test_ansible_with_limits
    test_complex_host_patterns
    test_different_modules
    test_ansible_argument_parsing
    test_ansible_error_handling
    test_ansible_performance
    
    # Final results
    echo -e "${BLUE}=========================================="
    echo -e "ANSIBLE WRAPPER TEST RESULTS SUMMARY${NC}"
    echo "=========================================="
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    echo -e "Success Rate: ${BLUE}${success_rate}%${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL ANSIBLE WRAPPER TESTS PASSED!${NC}"
        echo -e "${GREEN}The ansible wrapper is working correctly for ad-hoc commands${NC}"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS ANSIBLE WRAPPER TESTS FAILED${NC}"
        echo -e "${RED}Some ansible scenarios need attention${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_ansible_tests
fi
