param (
   [switch]$debugflag = $false,
   [string]$config_file = ".\config.ini"
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

# read in the config file config.ini 
$ini = Get-IniContent($config_file)

# common headers
$headers = (@{'accept' = 'application/json'})

$output_lines = New-Object System.Collections.ArrayList($null)

# loop for each section in the config file (except the common section)
$clusters = $ini.keys | Select-String -NotMatch "common"
foreach ($cluster in $clusters) {
    $cluster = [string]$cluster    # cast as string (type MatchInfo initially)

    # read in the credential from the path provided in the config file
    $cred = Import-Clixml -Path $ini[$cluster]["credential_path"]

    # get the actual cluster name of the cluster
    $cluster_name = ""
    $url = "https://" + $ini[$cluster]["ontap_cluster"] + "/api/cluster"
    $response = Invoke-WebRequest $url -Method 'GET' -Credential $cred -UseBasicParsing -Headers $headers
    if ([System.Net.HttpStatusCode]$response.StatusCode -eq "OK") {
        $json_response = $response.Content | ConvertFrom-Json
        $cluster_name = $json_response.name
    }

    # get the cifs protocol connections from this ONTAP cluster
    $connections = @{}
    $url = "https://" + $ini[$cluster]["ontap_cluster"] + "/api/protocols/cifs/connections?fields=*&return_records=true"
    $response = Invoke-WebRequest $url -Method 'GET' -Credential $cred -UseBasicParsing  -Headers $headers
    if ([System.Net.HttpStatusCode]$response.StatusCode -eq "OK") {
        $json_response = $response.Content | ConvertFrom-Json
        foreach ($record in $json_response.records) {
            $connections[$record.identifier] = $record.server_ip + "," + $record.svm.name + "," + $record.client_ip 
        }
    }

    # get the cifs protocol sessions from this ONTAP cluster
    $sessions = @{}
    $url = "https://" + $ini[$cluster]["ontap_cluster"] + "/api/protocols/cifs/sessions?fields=*&return_records=true"
    $response = Invoke-WebRequest $url -Method 'GET' -Credential $cred -UseBasicParsing  -Headers $headers
    if ([System.Net.HttpStatusCode]$response.StatusCode -eq "OK") {
        $json_response = $response.Content | ConvertFrom-Json
        foreach ($record in $json_response.records) {
            $sessions[$record.connection_id] = $record.user + "," + $record.protocol
        }
    }

    # stitch together the connection and session information
    foreach ($key in $connections.Keys) {
        if ($sessions.ContainsKey($key)) {
            $line = $cluster_name + "," + $connections[$key] + "," + $sessions[$key]
            [void]$output_lines.Add($cluster_name + "," + $connections[$key] + "," + $sessions[$key])
        }
    }

}

# add any new unique entries to the output file
$existing_lines = Get-Content -Path $ini["common"]["output_file"]
$existing_lines = $existing_lines + @($output_lines) | sort  -Unique 
$existing_lines | Out-File -FilePath $ini["common"]["output_file"]


