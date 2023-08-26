# Login to Azure (if required)

add-azaccount -UseDeviceAuthentication

# Get ARM token for accessing Azure VM
$ARMToken = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/'

# variables
$subId = '681512a3-2969-4449-b1b0-5b8dcad20059'
$vmRg = 'rg-ae-el-2023'
$vmName = 'vm-el2023-001'
$kvName = 'kv-el2023-001'
# Invoke command on Azure Vm - Get oAuth token for the VM managed identity for accessing key vaults

$vmCommand = @(
  "((invoke-webrequest -Headers @{Metadata='true'} -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net' -UseBasicParsing).content | convertfrom-json).access_token"
)
$vmRunCmdUri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$vmRg/providers/Microsoft.Compute/virtualMachines/$vmName/runCommand?api-version=2023-07-01"

$vmRunCmdBody = @{
  commandId = 'RunPowerShellScript'
  script    = $vmCommand
} | ConvertTo-Json
$vmRunCmdHeaders = @{
  Authorization  = "Bearer $($ARMToken.Token)"
  'Content-Type' = 'application/json'
}
$vmRunCmdRequest = invoke-webrequest -Uri $vmRunCmdUri -Method POST -Headers $vmRunCmdHeaders -Body $vmRunCmdBody

$AsyncOpsUri = $vmRunCmdRequest.Headers.'Azure-AsyncOperation'[0]
$runCompleted = $false
Do {
  Write-Verbose "Wait 5 seconds" -verbose
  start-sleep -seconds 5
  $now = Get-Date
  Write-Verbose "Checking status via '$AsyncOpsUri'" -verbose
  #Make sure token is not expired
  $checkResult = Invoke-WebRequest -uri $AsyncOpsUri -Method GET -Headers $vmRunCmdHeaders
  $checkResultStatus = ($checkResult.content | convertfrom-Json).status
  Write-Verbose "Current Status: $checkResultStatus" -verbose
  if ($checkResultStatus -ine 'inprogress') {
    $runCompleted = $true
  }
} until ($runCompleted -eq $true)
$vmRunCmdResult = $checkResult.content | convertfrom-Json
$kvToken = $vmRunCmdResult.properties.output.value | where-object { $_.code -eq "ComponentStatus/StdOut/succeeded" } | foreach-object { $_.message }

# Access Key Vault
$kvSecretsUri = "https://$kvName.vault.azure.net/secrets?api-version=7.4"
$kvHeaders = @{
  Authorization  = "Bearer $kvToken"
  'Content-Type' = 'application/json'
}
#Get all secrets
$kvSecretsRequest = Invoke-WebRequest -uri $kvSecretsUri -Method GET -Headers $kvHeaders

#First secret
$kvSecret = ($kvSecretsRequest.content | convertfrom-Json).value[0]

#First secret Uri
$kvSecretUri = $kvSecret.id
$kvSecretVersionsUri = "$kvSecretUri/versions?api-version=7.4"

#Get all versions
$kvSecretVersions = Invoke-WebRequest -uri $kvSecretVersionsUri -Method GET -Headers $kvHeaders
$kVSecretLatestVersion = ($kvSecretVersions.content | convertfrom-json).value | Sort-Object $_.attributes.created -Descending | select-object -first 1

#Get KV secret value
$kvSecretValueUri = "$($kvSecretLatestVersion.id)?api-version=7.4"
$kvSecretValueRequest = Invoke-WebRequest -uri $kvSecretValueUri -Method GET -Headers $kvHeaders
$kvSecretValue = ($kvSecretValueRequest.content | convertfrom-json).value

Write-output "The Key Vault secret value is: '$kvSecretValue'"