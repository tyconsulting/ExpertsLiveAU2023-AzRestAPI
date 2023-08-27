#!/bin/bash
#Sign in
az login --use-device-code
token=$(az account get-access-token | jq -r .accessToken)

#variables
subid='681512a3-2969-4449-b1b0-5b8dcad20059'
rg='rg-ae-el-2023'
storage_account='sataoel2023demo01'
storage_uri="https://management.azure.com/subscriptions/$subid/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$storage_account?api-version=2023-01-01"

curl $storage_uri -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X GET | jq
