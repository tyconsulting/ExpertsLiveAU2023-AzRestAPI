# Login to Azure (if required)

add-azaccount -UseDeviceAuthentication

# Get tokens
$ARMToken = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/'
$MSGraphToken = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com/'

# variables
$subId =
# Invoke command on Azure Vm
$vmCommand = '((invoke-webrequest -Headers @{Metadata="true"} -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net/").content | convertfrom-json).access_token'