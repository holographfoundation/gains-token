#!/bin/bash

# Create abis directory if it doesn't exist
mkdir -p abis

# Find all Solidity files and process each one
find src -name "*.sol" | while read -r file; do
    # Extract the filename without extension and path
    filename=$(basename "$file" .sol)
    
    # Generate ABI using forge inspect
    echo "Generating ABI for $filename..."
    
    # Run forge inspect and save the output directly
    if forge inspect "$filename" abi 2>/dev/null > "abis/$filename.json"; then
        echo "✓ Successfully generated ABI for $filename"
    else
        echo "✗ Failed to generate ABI for $filename"
    fi
done

echo "ABI generation complete. Check the abis/ directory for the generated files."

