param (
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Display script info
Write-Host "Transforming npx commands in $FilePath"

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

try {
    # Read the JSON file content
    $json = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    
    # Track modifications
    $modifiedCount = 0
    
    # Process each server configuration
    foreach ($serverName in $json.mcpServers.PSObject.Properties.Name) {
        $server = $json.mcpServers.$serverName
        
        # Check if we have a "cmd" command with "/c", "npx", "-y" pattern
        if ($server.command -eq "cmd" -and 
            $server.args -and 
            $server.args.Count -ge 3 -and 
            $server.args[0] -eq "/c" -and 
            $server.args[1] -eq "npx" -and 
            $server.args[2] -eq "-y") {
            
            # Modify the configuration
            $server.command = "npx"
            
            # Remove the "/c" element (at index 0)
            # Also remove "npx" (at index 1), since it's now the command
            $server.args = $server.args[2..$server.args.Length]
            
            $modifiedCount++
        }
    }
    
    # Save the modified JSON back to the file
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    
    Write-Host "Modified $modifiedCount server configurations successfully!"
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}