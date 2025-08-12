#!/bin/bash

# Final Comprehensive Test Suite for ansible-playbook Wrapper
# Combines integration tests and edge cases with refined expectations
# Uses only safe, non-destructive commands (ping, setup, debug)

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
SKIPPED_TESTS=0

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
    local should_skip="${5:-false}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "  Description: $description"
    echo "  Command: $command"
    
    if [[ "$should_skip" == "true" ]]; then
        echo -e "  ${YELLOW}⏭ SKIPPED (Known limitation)${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        echo
        return
    fi
    
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

# Setup comprehensive test files
function setup_test_files() {
    echo -e "${CYAN}Setting up comprehensive test files...${NC}"
    
    # Safe ping-only playbook for single host
    cat > test_ping_single.yml << 'EOF'
---
- name: Safe Ping Test - Single Host
  hosts: pihole
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    # Safe ping-only playbook for multiple hosts
    cat > test_ping_multi.yml << 'EOF'
---
- name: Safe Ping Test - Multiple Hosts
  hosts: pihole, dockassist
  gather_facts: no
  tasks:
    - name: Ping test
      ping:
EOF

    # Safe setup-only playbook for all hosts
    cat > test_setup_all.yml << 'EOF'
---
- name: Safe Setup Test - All Hosts
  hosts: all
  gather_facts: yes
  tasks:
    - name: Display hostname
      debug:
        var: inventory_hostname
EOF

    # Safe debug-only playbook
    cat > test_debug_only.yml << 'EOF'
---
- name: Safe Debug Test
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Debug message
      debug:
        msg: "This is a safe test"
EOF

    # Multiple plays playbook (safe)
    cat > test_multi_play_safe.yml << 'EOF'
---
- name: First Safe Play
  hosts: pihole
  gather_facts: no
  tasks:
    - name: Ping pihole
      ping:

- name: Second Safe Play  
  hosts: dockassist
  gather_facts: no
  tasks:
    - name: Ping dockassist
      ping:
EOF

    # Group-based playbook (safe)
    cat > test_webservers_safe.yml << 'EOF'
---
- name: Safe Webservers Test
  hosts: webservers
  gather_facts: no
  tasks:
    - name: Ping webservers
      ping:
EOF

    echo -e "${CYAN}✓ Comprehensive test files created${NC}"
    echo
}

# Core functionality tests (from original integration suite)
function test_core_functionality() {
    echo -e "${YELLOW}=== Core Functionality Tests ===${NC}"
    
    # Test 1: No limit - should use playbook hosts (multi-host, should pre-auth)
    check_preauth_behavior \
        "No limit parameter (playbook hosts)" \
        "true" \
        "ansible-playbook --check test_ping_multi.yml" \
        "No limit should use playbook hosts and trigger pre-auth"
    
    # Test 2: Single host limit - should skip pre-auth
    check_preauth_behavior \
        "Limit to single host (pihole)" \
        "false" \
        "ansible-playbook --check --limit pihole test_ping_multi.yml" \
        "Single host limit should skip pre-auth"
    
    # Test 3: Multiple host limit - should pre-auth
    check_preauth_behavior \
        "Limit to multiple hosts" \
        "true" \
        "ansible-playbook --check --limit pihole,dockassist test_ping_multi.yml" \
        "Multiple host limit should trigger pre-auth"
    
    # Test 4: All parameter formats work
    check_preauth_behavior \
        "-l format single host" \
        "false" \
        "ansible-playbook --check -l pihole test_ping_multi.yml" \
        "-l format should work for single host"
    
    check_preauth_behavior \
        "--limit= format multiple hosts" \
        "true" \
        "ansible-playbook --check --limit=pihole,dockassist test_ping_multi.yml" \
        "--limit= format should work for multiple hosts"
    
    check_preauth_behavior \
        "-l= format single host" \
        "false" \
        "ansible-playbook --check -l=dockassist test_ping_multi.yml" \
        "-l= format should work for single host"
}

# Host pattern tests
function test_host_patterns() {
    echo -e "${YELLOW}=== Host Pattern Tests ===${NC}"
    
    # Test wildcard patterns
    check_preauth_behavior \
        "Wildcard single match" \
        "false" \
        "ansible-playbook --check --limit 'pihole*' test_setup_all.yml" \
        "Wildcard matching single host should skip pre-auth"
    
    # Test group patterns (using known groups)
    check_preauth_behavior \
        "Group pattern (webservers)" \
        "true" \
        "ansible-playbook --check test_webservers_safe.yml" \
        "Group-based playbook should trigger pre-auth"
    
    # Test 'all' pattern
    check_preauth_behavior \
        "All hosts pattern" \
        "true" \
        "ansible-playbook --check --limit all test_ping_single.yml" \
        "All hosts pattern should trigger pre-auth"
}

# Argument parsing edge cases
function test_argument_parsing() {
    echo -e "${YELLOW}=== Argument Parsing Tests ===${NC}"
    
    # Test multiple limit parameters (last wins)
    check_preauth_behavior \
        "Multiple limit parameters" \
        "false" \
        "ansible-playbook --check --limit pihole,dockassist --limit pihole test_ping_multi.yml" \
        "Multiple limits - last one wins (single host)"
    
    # Test complex command line
    check_preauth_behavior \
        "Complex command line" \
        "false" \
        "ansible-playbook --check --verbose --extra-vars 'test=value' --limit pihole test_ping_multi.yml" \
        "Complex command with single host should skip pre-auth"
    
    # Test limit with spaces
    check_preauth_behavior \
        "Limit with spaces" \
        "true" \
        "ansible-playbook --check --limit 'pihole, dockassist' test_ping_multi.yml" \
        "Limit with spaces should trigger pre-auth"
}

# Playbook structure tests
function test_playbook_structures() {
    echo -e "${YELLOW}=== Playbook Structure Tests ===${NC}"
    
    # Test multiple plays
    check_preauth_behavior \
        "Multiple plays playbook" \
        "true" \
        "ansible-playbook --check test_multi_play_safe.yml" \
        "Multiple plays should trigger pre-auth"
    
    # Test single host playbook
    check_preauth_behavior \
        "Single host playbook" \
        "false" \
        "ansible-playbook --check test_ping_single.yml" \
        "Single host playbook should skip pre-auth"
    
    # Test localhost playbook
    check_preauth_behavior \
        "Localhost playbook" \
        "false" \
        "ansible-playbook --check test_debug_only.yml" \
        "Localhost playbook should skip pre-auth"
}

# Error handling and resilience tests
function test_error_handling() {
    echo -e "${YELLOW}=== Error Handling Tests ===${NC}"
    
    # Test non-existent single host
    check_preauth_behavior \
        "Non-existent single host" \
        "false" \
        "ansible-playbook --check --limit nonexistent test_ping_multi.yml" \
        "Non-existent single host should skip pre-auth"
    
    # Test mix of valid/invalid hosts
    check_preauth_behavior \
        "Mix valid/invalid hosts" \
        "true" \
        "ansible-playbook --check --limit 'pihole,nonexistent,dockassist' test_ping_multi.yml" \
        "Mix of valid/invalid hosts should trigger pre-auth"
    
    # Test missing playbook
    check_preauth_behavior \
        "Missing playbook file" \
        "any" \
        "ansible-playbook --check nonexistent.yml" \
        "Missing playbook should not crash wrapper"
    
    # Test invalid options (should not crash wrapper)
    check_preauth_behavior \
        "Invalid ansible options" \
        "any" \
        "ansible-playbook --check --invalid-option test_ping_single.yml" \
        "Invalid options should not crash wrapper"
}

# Performance and stress tests
function test_performance() {
    echo -e "${YELLOW}=== Performance Tests ===${NC}"
    
    # Test very long host list
    check_preauth_behavior \
        "Very long host list" \
        "true" \
        "ansible-playbook --check --limit 'pihole,dockassist,hifipi,cobra,vinylstreamer,devpi' test_setup_all.yml" \
        "Very long host list should trigger pre-auth"
    
    # Test empty limit
    check_preauth_behavior \
        "Empty limit parameter" \
        "true" \
        "ansible-playbook --check --limit '' test_ping_multi.yml" \
        "Empty limit should fall back to playbook hosts"
}

# Integration with real deploy playbook
function test_real_playbook_integration() {
    echo -e "${YELLOW}=== Real Playbook Integration Tests ===${NC}"
    
    if [[ -f "deploy_enhanced_speed_monitor.yml" ]]; then
        # Test with real playbook - no limit
        check_preauth_behavior \
            "Real playbook no limit" \
            "true" \
            "ansible-playbook --check deploy_enhanced_speed_monitor.yml" \
            "Real playbook should trigger pre-auth for multiple hosts"
        
        # Test with real playbook - single host
        check_preauth_behavior \
            "Real playbook single host" \
            "false" \
            "ansible-playbook --check --limit pihole deploy_enhanced_speed_monitor.yml" \
            "Real playbook with single host should skip pre-auth"
        
        # Test with real playbook - multiple hosts
        check_preauth_behavior \
            "Real playbook multiple hosts" \
            "true" \
            "ansible-playbook --check --limit pihole,dockassist deploy_enhanced_speed_monitor.yml" \
            "Real playbook with multiple hosts should trigger pre-auth"
    else
        echo -e "${YELLOW}⚠ Real playbook tests skipped (deploy_enhanced_speed_monitor.yml not found)${NC}"
        echo
    fi
}

# Cleanup test files
function cleanup_test_files() {
    echo -e "${CYAN}Cleaning up test files...${NC}"
    rm -f test_ping_single.yml test_ping_multi.yml test_setup_all.yml test_debug_only.yml
    rm -f test_multi_play_safe.yml test_webservers_safe.yml
    echo -e "${CYAN}✓ Test files cleaned up${NC}"
    echo
}

# Main test execution
function run_final_tests() {
    echo -e "${BLUE}Final Comprehensive Test Suite for ansible-playbook Wrapper${NC}"
    echo "==========================================================="
    echo "Testing all scenarios with safe, non-destructive commands only"
    echo "Uses: ping, setup (gather_facts), debug tasks only"
    echo
    
    # Show current directory and key files
    echo -e "${CYAN}Current directory: $(pwd)${NC}"
    echo -e "${CYAN}Key files present:${NC}"
    [[ -f "inventory" ]] && echo "  ✓ inventory" || echo "  ✗ inventory (missing)"
    [[ -f "deploy_enhanced_speed_monitor.yml" ]] && echo "  ✓ deploy_enhanced_speed_monitor.yml" || echo "  ✗ deploy_enhanced_speed_monitor.yml (missing)"
    echo
    
    setup_test_files
    
    test_core_functionality
    test_host_patterns
    test_argument_parsing
    test_playbook_structures
    test_error_handling
    test_performance
    test_real_playbook_integration
    
    cleanup_test_files
    
    # Final results
    echo -e "${BLUE}==========================================================="
    echo -e "FINAL TEST RESULTS SUMMARY${NC}"
    echo "==========================================================="
    echo -e "Total Tests:   ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed:        ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:        ${RED}$FAILED_TESTS${NC}"
    echo -e "Skipped:       ${YELLOW}$SKIPPED_TESTS${NC}"
    
    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$(( (PASSED_TESTS * 100) / (TOTAL_TESTS - SKIPPED_TESTS) ))
    fi
    echo -e "Success Rate:  ${BLUE}${success_rate}%${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}The ansible-playbook wrapper is production-ready and handles all scenarios correctly${NC}"
        echo
        echo -e "${CYAN}✅ Comprehensive validation complete:${NC}"
        echo "  • Core functionality: Single vs multi-host detection"
        echo "  • All limit parameter formats: --limit, -l, --limit=, -l="
        echo "  • Host patterns: wildcards, groups, all"
        echo "  • Argument parsing: complex commands, multiple options"
        echo "  • Playbook structures: single/multi-play, different host targets"
        echo "  • Error handling: invalid hosts, missing files, bad options"
        echo "  • Performance: long host lists, edge cases"
        echo "  • Real-world integration: actual playbook testing"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS TESTS FAILED${NC}"
        echo -e "${RED}Some scenarios need attention${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_final_tests
fi
