#!/bin/bash

# bash_coverage.sh - Simple bash code coverage tool
# Tracks which lines are executed during script runs

set -euo pipefail

# Configuration
COVERAGE_DIR="${COVERAGE_DIR:-coverage}"
COVERAGE_DATA_FILE="$COVERAGE_DIR/coverage.data"
COVERAGE_REPORT_FILE="$COVERAGE_DIR/coverage.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# Initialize coverage tracking
init_coverage() {
    mkdir -p "$COVERAGE_DIR"
    true > "$COVERAGE_DATA_FILE"
    print_color "$BLUE" "Coverage tracking initialized in $COVERAGE_DIR"
}

# Instrument a bash script for coverage tracking
instrument_script() {
    local input_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file $input_file not found" >&2
        return 1
    fi
    
    print_color "$BLUE" "Instrumenting $input_file -> $output_file"
    
    # Create instrumented version with line tracking
    {
        echo "#!/bin/bash"
        echo "# Instrumented version of $input_file"
        echo "COVERAGE_DATA_FILE='$COVERAGE_DATA_FILE'"
        echo "ORIGINAL_FILE='$input_file'"
        echo ""
        echo "# Coverage tracking function"
        echo "track_line() {"
        echo "    echo \"\$ORIGINAL_FILE:\$1\" >> \"\$COVERAGE_DATA_FILE\""
        echo "}"
        echo ""
        
        # Process each line of the original script
        local line_num=1
        local in_function=0
        local in_case=0
        while IFS= read -r line; do
            # Track function and case statement nesting
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{?[[:space:]]*$ ]]; then
                ((in_function++))
            elif [[ "$line" =~ ^[[:space:]]*case[[:space:]] ]]; then
                ((in_case++))
            elif [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]] && [[ $in_function -gt 0 ]]; then
                ((in_function--))
            elif [[ "$line" =~ ^[[:space:]]*esac[[:space:]]*$ ]] && [[ $in_case -gt 0 ]]; then
                ((in_case--))
            fi
            
            # Skip shebang line
            if [[ $line_num -eq 1 && "$line" =~ ^#! ]]; then
                echo "# Original shebang: $line"
            elif [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                # Skip comments and empty lines
                echo "$line"
            elif [[ "$line" =~ ^[[:space:]]*$ ]]; then
                # Skip blank lines
                echo "$line"
            else
                # Add line tracking before executable lines
                # Simplified approach: only track top-level executable statements
                if [[ "$line" =~ ^[[:space:]]*# ]] || \
                   [[ "$line" =~ ^[[:space:]]*$ ]] || \
                   [[ "$line" =~ ^[[:space:]]*\{ ]] || \
                   [[ "$line" =~ ^[[:space:]]*\} ]] || \
                   [[ "$line" =~ ^[[:space:]]*fi[[:space:]]*$ ]] || \
                   [[ "$line" =~ ^[[:space:]]*done[[:space:]]*$ ]] || \
                   [[ "$line" =~ ^[[:space:]]*esac[[:space:]]*$ ]] || \
                   [[ "$line" =~ \(\)[[:space:]]*$ ]] || \
                   [[ "$line" =~ case.*in[[:space:]]*$ ]] || \
                   [[ "$line" =~ \)[[:space:]]*$ ]] || \
                   [[ $in_function -gt 0 ]] || [[ $in_case -gt 0 ]]; then
                    # Don't track structural elements or function/case content
                    echo "$line"
                else
                    # Add tracking for regular executable lines
                    echo "track_line $line_num"
                    echo "$line"
                fi
            fi
            ((line_num++))
        done < "$input_file"
    } > "$output_file"
    
    chmod +x "$output_file"
}

# Run script with coverage
run_with_coverage() {
    local script="$1"
    shift
    local args=("$@")
    
    local temp_dir
    temp_dir=$(mktemp -d -t coverage.XXXXXX)
    local instrumented_script
    instrumented_script="$temp_dir/$(basename "$script")"
    
    # Instrument the script
    instrument_script "$script" "$instrumented_script"
    
    print_color "$BLUE" "Running $script with coverage tracking..."
    
    # Run the instrumented script
    local exit_code=0
    bash "$instrumented_script" "${args[@]}" || exit_code=$?
    
    # Clean up
    rm -rf "$temp_dir"
    
    return $exit_code
}

# Analyze coverage data
analyze_coverage() {
    if [[ ! -f "$COVERAGE_DATA_FILE" ]]; then
        print_color "$RED" "No coverage data found. Run tests first."
        return 1
    fi
    
    print_color "$BLUE" "Analyzing coverage data..."
    
    # Get unique files covered
    local files
    mapfile -t files < <(cut -d: -f1 "$COVERAGE_DATA_FILE" | sort -u)
    
    local total_files=${#files[@]}
    local total_lines=0
    local covered_lines=0
    
    echo "Coverage Report"
    echo "=============="
    echo ""
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        # Count total executable lines in file
        local file_total_lines
        file_total_lines=$(grep -c -v -E '^\s*#|^\s*$' "$file")
        
        # Count covered lines for this file
        local file_covered_lines
        file_covered_lines=$(grep "^$file:" "$COVERAGE_DATA_FILE" | cut -d: -f2 | sort -u | wc -l)
        
        local coverage_percent=0
        if [[ $file_total_lines -gt 0 ]]; then
            coverage_percent=$((file_covered_lines * 100 / file_total_lines))
        fi
        
        # Color code based on coverage
        local color="$RED"
        if [[ $coverage_percent -ge 80 ]]; then
            color="$GREEN"
        elif [[ $coverage_percent -ge 60 ]]; then
            color="$YELLOW"
        fi
        
        print_color "$color" "$(printf "%-40s %3d/%3d lines (%3d%%)" "$(basename "$file")" "$file_covered_lines" "$file_total_lines" "$coverage_percent")"
        
        total_lines=$((total_lines + file_total_lines))
        covered_lines=$((covered_lines + file_covered_lines))
    done
    
    echo ""
    echo "Summary"
    echo "======="
    
    local overall_percent=0
    if [[ $total_lines -gt 0 ]]; then
        overall_percent=$((covered_lines * 100 / total_lines))
    fi
    
    local summary_color="$RED"
    if [[ $overall_percent -ge 80 ]]; then
        summary_color="$GREEN"
    elif [[ $overall_percent -ge 60 ]]; then
        summary_color="$YELLOW"
    fi
    
    print_color "$summary_color" "Overall Coverage: $covered_lines/$total_lines lines ($overall_percent%)"
    print_color "$BLUE" "Files analyzed: $total_files"
    
    # Return non-zero if coverage is below 80%
    if [[ $overall_percent -lt 80 ]]; then
        print_color "$YELLOW" "Warning: Coverage is below 80% threshold"
        return 1
    else
        print_color "$GREEN" "Coverage meets 80% threshold"
        return 0
    fi
}

# Generate HTML coverage report
generate_html_report() {
    if [[ ! -f "$COVERAGE_DATA_FILE" ]]; then
        print_color "$RED" "No coverage data found. Run tests first."
        return 1
    fi
    
    print_color "$BLUE" "Generating HTML coverage report..."
    
    cat > "$COVERAGE_REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Bash Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 10px; border-radius: 5px; }
        .file { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        .covered { background: #d4edda; }
        .partial { background: #fff3cd; }
        .uncovered { background: #f8d7da; }
        .line-numbers { background: #f8f9fa; padding: 5px; font-family: monospace; }
        .code { font-family: monospace; white-space: pre; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Bash Coverage Report</h1>
        <p>Generated on: $(date)</p>
    </div>
EOF
    
    # Add file coverage table
    {
        echo '<h2>File Coverage Summary</h2>'
        echo '<table>'
        echo '<tr><th>File</th><th>Lines Covered</th><th>Total Lines</th><th>Coverage %</th></tr>'
    } >> "$COVERAGE_REPORT_FILE"
    
    local files
    mapfile -t files < <(cut -d: -f1 "$COVERAGE_DATA_FILE" | sort -u)
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        local file_total_lines
        file_total_lines=$(grep -c -v -E '^\s*#|^\s*$' "$file")
        
        local file_covered_lines
        file_covered_lines=$(grep "^$file:" "$COVERAGE_DATA_FILE" | cut -d: -f2 | sort -u | wc -l)
        
        local coverage_percent=0
        if [[ $file_total_lines -gt 0 ]]; then
            coverage_percent=$((file_covered_lines * 100 / file_total_lines))
        fi
        
        local row_class="uncovered"
        if [[ $coverage_percent -ge 80 ]]; then
            row_class="covered"
        elif [[ $coverage_percent -ge 60 ]]; then
            row_class="partial"
        fi
        
        echo "<tr class=\"$row_class\"><td>$(basename "$file")</td><td>$file_covered_lines</td><td>$file_total_lines</td><td>$coverage_percent%</td></tr>" >> "$COVERAGE_REPORT_FILE"
    done
    
    {
        echo '</table>'
        echo '</body></html>'
    } >> "$COVERAGE_REPORT_FILE"
    
    print_color "$GREEN" "HTML report generated: $COVERAGE_REPORT_FILE"
}

# Clean coverage data
clean_coverage() {
    if [[ -d "$COVERAGE_DIR" ]]; then
        rm -rf "$COVERAGE_DIR"
        print_color "$BLUE" "Coverage data cleaned"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    init                Initialize coverage tracking
    run <script> [args] Run script with coverage tracking
    analyze             Analyze coverage data and show report
    html                Generate HTML coverage report
    clean               Clean coverage data

Environment Variables:
    COVERAGE_DIR        Directory for coverage data (default: coverage)

Example:
    $0 init
    $0 run ./my_script.sh arg1 arg2
    $0 analyze
    $0 html
EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        "init")
            init_coverage
            ;;
        "run")
            if [[ $# -eq 0 ]]; then
                echo "Error: Script path required" >&2
                exit 1
            fi
            run_with_coverage "$@"
            ;;
        "analyze")
            analyze_coverage
            ;;
        "html")
            generate_html_report
            ;;
        "clean")
            clean_coverage
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi