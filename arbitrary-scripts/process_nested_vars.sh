#!/bin/bash

# Script to replace nested variables with their innermost values
# Usage: ./process_nested_vars.sh <input_file> [output_file]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo "If output_file is not specified, results will be printed to stdout"
    exit 1
fi

input_file="$1"
output_file="$2"

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found"
    exit 1
fi

# Function to process nested variables using sed
process_nested_variables() {
    local content="$1"
    local changed=1
    local temp_file=$(mktemp)
    
    # Keep processing until no more changes are made
    while [ $changed -eq 1 ]; do
        changed=0
        
        # Use sed to find and replace nested variables
        # Pattern: ${...${...}...} -> ${...}
        # This finds the outermost ${...} that contains exactly one inner ${...}
        local new_content=$(echo "$content" | sed -E '
            # Find patterns like ${...${...}...} and replace with ${...}
            s/\$\{[^{}]*\{([^{}]*)\}[^{}]*\}/\${\1}/g
        ')
        
        # Check if any changes were made
        if [ "$new_content" != "$content" ]; then
            changed=1
            content="$new_content"
        fi
    done
    
    echo "$content"
}

# Alternative approach using awk for better performance
process_variables_awk() {
    local content="$1"
    local changed=1
    
    while [ $changed -eq 1 ]; do
        changed=0
        
        # Use awk to process the content
        local new_content=$(echo "$content" | awk '
        {
            line = $0
            # Find and replace nested variables
            # Pattern: ${...${...}...} -> ${...}
            while (match(line, /\$\{[^{}]*\{([^{}]*)\}[^{}]*\}/)) {
                inner_var = substr(line, RSTART + RLENGTH - 1, 1)
                # Extract the inner variable content
                inner_start = RSTART
                inner_end = RSTART + RLENGTH - 1
                
                # Find the innermost ${...} within this match
                inner_match = substr(line, RSTART, RLENGTH)
                if (match(inner_match, /\$\{[^{}]*\}/)) {
                    inner_content = substr(inner_match, RSTART + 2, RLENGTH - 3)
                    # Replace the outer variable with the inner one
                    line = substr(line, 1, RSTART - 1) "${" inner_content "}" substr(line, RSTART + RLENGTH)
                }
            }
            print line
        }')
        
        # Check if any changes were made
        if [ "$new_content" != "$content" ]; then
            changed=1
            content="$new_content"
        fi
    done
    
    echo "$content"
}

# Read the input file
content=$(cat "$input_file")

# Process the content using sed approach
result=$(process_nested_variables "$content")

# Output the result
if [ -n "$output_file" ]; then
    echo "$result" > "$output_file"
    echo "Processed content written to: $output_file"
else
    echo "$result"
fi 