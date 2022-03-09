#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh


echo "Deleting the functionapp"

  az functionapp delete \
    --name "$DIRECT_FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_NAME"

echo "Now Deleting the functionapp plan, otherwise leaving the plan could incur more charges"
 az functionapp plan delete \
     --name "$PLAN_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --subscription "$SUBSCRIPTION_NAME" \
     --yes