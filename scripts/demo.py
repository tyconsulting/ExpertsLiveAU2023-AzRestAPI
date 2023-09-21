import subprocess
import json
import requests
#Sign in
# Run the Azure CLI command to sign in
subprocess.run(['az', 'login', '--use-device-code'])

#variables
subid='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
rg='rg-ae-el-2023'
storage_account='xxxxxxxx'
storage_uri=f"https://management.azure.com/subscriptions/{subid}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{storage_account}?api-version=2023-01-01"

# Run the Azure CLI command to get the access token
result = subprocess.run(['az', 'account', 'get-access-token'], capture_output=True)

# Get the access token from the output
response = json.loads(result.stdout.decode('utf-8'))
access_token = response["accessToken"]

# Set the request headers
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

#invoke REST API
response = requests.get(storage_uri, headers=headers)
#Process result
result=json.loads(response.content)
formatted_result=json.dumps(result, indent=4, sort_keys=True)
print(formatted_result)