param (
   [switch]$debugFlag = $false,
   [Parameter(mandatory=$true)][string]$outputFile 
)

# make sure that the file does not already exist
if (Test-Path -Path $outputFile) {
   Write-Host "The file $output_file already exists. Please delete the file first if you wish to overwrite it."
   exit 1
}

Get-Credential | Export-Clixml -Path $outputFile
