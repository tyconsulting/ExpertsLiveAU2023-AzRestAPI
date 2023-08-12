# Login to Azure (if required)

add-azaccount -UseDeviceAuthentication

# Get tokens
$ARMToken = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/'
$MSGraphToken = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com/'

# variables
$subId =
# Invoke command on Azure Vm
$vmCommand = "Get-ComputerInfo"