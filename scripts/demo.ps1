# Login to Azure (if required)

add-azaccount -UseDeviceAuthentication

# variables
$subId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
$vmRg = 'rg-ae-el-2023'
$vmName = 'vm-el2023-001'
$kvName = 'kv-el2023-001'

# Get ARM token for accessing Azure VM
$ARMToken = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/'

# Invoke command on Azure Vm - Get oAuth token for the VM managed identity for accessing key vaults
# command to be executed on the VM to get the oAuth token for Key Vault
$vmCommand = @(
  "((invoke-webrequest -Headers @{Metadata='true'} -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net' -UseBasicParsing).content | convertfrom-json).access_token"
)

#VM Run Command REST API URI
$vmRunCmdUri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$vmRg/providers/Microsoft.Compute/virtualMachines/$vmName/runCommand?api-version=2023-07-01"

#VM Run Command request body
$vmRunCmdBody = @{
  commandId = 'RunPowerShellScript'
  script    = $vmCommand
} | ConvertTo-Json

#VM Run Command request header
$vmRunCmdHeaders = @{
  Authorization  = "Bearer $($ARMToken.Token)"
  'Content-Type' = 'application/json'
}
#Invoke VM Run Command
$vmRunCmdRequest = invoke-webrequest -Uri $vmRunCmdUri -Method POST -Headers $vmRunCmdHeaders -Body $vmRunCmdBody

# Keep polling the VM Run Command result until it is completed
$AsyncOpsUri = $vmRunCmdRequest.Headers.'Azure-AsyncOperation'[0]
$runCompleted = $false
Do {
  Write-Verbose "Wait 5 seconds" -verbose
  start-sleep -seconds 5
  Write-Verbose "Checking status via '$AsyncOpsUri'" -verbose

  $checkResult = Invoke-WebRequest -uri $AsyncOpsUri -Method GET -Headers $vmRunCmdHeaders
  $checkResultStatus = ($checkResult.content | convertfrom-Json).status
  Write-Verbose "Current Status: $checkResultStatus" -verbose
  if ($checkResultStatus -ine 'inprogress') {
    $runCompleted = $true
  }
} until ($runCompleted -eq $true)

#Get VM Run Command result
$vmRunCmdResult = $checkResult.content | convertfrom-Json

#Extract the oAuth token for the key vault from the VM Run Command result
$kvToken = $vmRunCmdResult.properties.output.value | where-object { $_.code -eq "ComponentStatus/StdOut/succeeded" } | foreach-object { $_.message }

# Access Key Vault
$kvSecretsUri = "https://$kvName.vault.azure.net/secrets?api-version=7.4"
$kvHeaders = @{
  Authorization  = "Bearer $kvToken"
  'Content-Type' = 'application/json'
}
#Get all secrets
$kvSecretsRequest = Invoke-WebRequest -uri $kvSecretsUri -Method GET -Headers $kvHeaders
$AllKvSecrets = ($kvSecretsRequest.content | convertfrom-Json).value
#Loop through all the secrets in KV
$i = 1
foreach ($kvSecret in $AllKvSecrets) {

  #secret name
  $secretName = $kvSecret.id.split('/')[-1]
  # secret Uri
  $kvSecretUri = $kvSecret.id
  $kvSecretVersionsUri = "$kvSecretUri/versions?api-version=7.4"

  #Get all versions
  $kvSecretVersions = Invoke-WebRequest -uri $kvSecretVersionsUri -Method GET -Headers $kvHeaders
  $kVSecretLatestVersion = ($kvSecretVersions.content | convertfrom-json).value | select-object -Last 1
  #Get KV secret value
  $kvSecretValueUri = "$($kvSecretLatestVersion.id)?api-version=7.4"
  $kvSecretValueRequest = Invoke-WebRequest -uri $kvSecretValueUri -Method GET -Headers $kvHeaders
  $kvSecretValue = ($kvSecretValueRequest.content | convertfrom-json).value
  Write-output "$i. The value for secret '$secretName' is: '$kvSecretValue'"
  $i++
}
