param (
   [switch]$debugFlag = $false,
   [string]$configFile = ".\config.ini"
)

# this is to ignore the self-signed certificate 
try {
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
} catch {}
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# function to parse .ini file
function Get-IniContent ($in_filepath) {
    $ini = @{}
    switch -regex -file $in_filepath
    {
        "^\[(.+)\]" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        "^(;.*)$" # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        }
        "^(.+?)\s*=\s*(.+?)\s*$" # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}

Write-Host "--------------------------------"

# Check that the config file exists
Write-Host "Checking if the config file exists"
if (-not (Test-Path -Path $configFile)) {
   Write-Host "The config file $configFile does not exist"
   exit 1
}

# read in the config file config.ini 
Write-Host "Reading config file $configFile"
try {
    $ini = Get-IniContent($configFile)
} 
catch {
    Write-Host "Error reading config file $configFile"
    exit 1
}

# test the common section of the config file 
Write-Host "Checking if the config file contains a 'common' section"
if (-not $ini.ContainsKey("common")) {
    Write-Host "Cannot find a 'common' section in the config file $configFile"
    exit 1
}

# the common section in the config file should only contain one item
Write-Host "Checking the number of items in the 'common' section of the config file"
if ($ini["common"].Count -ne 1) {
    Write-Host "Too many number of items in the 'common' section of the config file, expected 1 got $($ini["common"].Count)"
    exit 1
}

# make sure that the only item in the common section is 'output_file'
Write-Host "Checking item name(s) in the 'common' section of the config file"
if (-not $ini["common"].ContainsKey("output_file")) {
    Write-Host "Cannot find the item 'output_file' in the 'common' section of the config file"
    exit 1
}

# check the number of element in each of the non-common sections of the config file 
$clusters = $ini.keys | Select-String -NotMatch "common"
Write-Host "Checking the number of elements in the non-common sections of the config file"
foreach ($cluster in $clusters) {
    $cluster = [string]$cluster    # cast as string (type MatchInfo initially)
    if ($ini[$cluster].Count -ne 2) {
        Write-Host "Wrong number of items in the $cluster section of the config file, expected 2 got $($ini[$cluster].Count)"
        exit 1
    }
}

# check the name of the items in the non-common sections of the config file
$clusters = $ini.keys | Select-String -NotMatch "common"
Write-Host "Checking the name of the items in the non-common sections of the config file"
foreach ($cluster in $clusters) {
    $cluster = [string]$cluster    # cast as string (type MatchInfo initially)
    if ((-not $ini[$cluster].ContainsKey("ontap_cluster")) -and (-not $ini[$cluster].ContainsKey("credential_file"))) {
        Write-Host "Unexpected item name in the $cluster section of the config file"
        exit 1
    }
}

Write-Host "--------------------------------"

# common headers
$headers = (@{'accept' = 'application/json'})

# loop for each section in the config file (except the common section)
$clusters = $ini.keys | Select-String -NotMatch "common"
foreach ($cluster in $clusters) {

    $cluster = [string]$cluster    # cast as string (type MatchInfo initially)
    Write-Host "Beginning testing of cluster $cluster"

    # read in the credential from the path provided in the config file
    Write-Host "Reading credential from $($ini[$cluster]["credential_path"])"
    try {
        $cred = Import-Clixml -Path $ini[$cluster]["credential_path"]
    }
    catch {
        Write-Host "Could not import credential for cluster $cluster from file $($ini[$cluster]["credential_path"])"
        exit 1
    }

    # send getVersion API to cluster
    Write-Host "Getting ONTAP version for cluster $cluster"
    $cluster_name = ""
    $url = "https://" + $ini[$cluster]["ontap_cluster"] + "/api/cluster"
    try {
        $response = Invoke-WebRequest $url -Method 'GET' -Credential $cred -UseBasicParsing -Headers $headers
        if ([System.Net.HttpStatusCode]$response.StatusCode -eq "OK") {
            $json_response = $response.Content | ConvertFrom-Json
            Write-Host "Cluster $cluster has version $($json_response.version.full)"
        }
        else {
            Write-Host "Could not complete REST API call for $cluster, HTTP status code $($response.StatusCode)"
            exit 1
        }
    }
    catch {
        Write-Host "Could not complete /api/cluster REST API call for $cluster"
        exit 1
    }

    Write-Host "--------------------------------"
}

# if you reached this far then everything is ok 
Write-Host "CHECK_CONFIG.PS1 COMPLETED SUCCESSFULLY"
exit 0


