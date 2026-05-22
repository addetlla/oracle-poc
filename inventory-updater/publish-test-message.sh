#!/bin/bash

# Usage: ./publish-test-message.sh <minutes_to_run>
# Example: ./publish-test-message.sh 2

if [ -z "$1" ]; then
  echo "Please provide the number of minutes to run the script."
  echo "Usage: ./publish-test-message.sh <minutes_to_run>"
  exit 1
fi

END_TIME=$((SECONDS + $1 * 60))
ITEMS=("BEEF-PATTY-4" "BUN-SESAME" "FRIES-CRINKLE")

echo "Running inventory updates for $1 minute(s)..."

while [ $SECONDS -lt $END_TIME ]; do
  RANDOM_ITEM=${ITEMS[$RANDOM % ${#ITEMS[@]}]}
  RANDOM_QTY=$((RANDOM % 20 + 1))

  echo "Publishing update: $RANDOM_ITEM by $RANDOM_QTY"

  curl -s -o /dev/null -u guest:guest -H "content-type:application/json" \
    -X POST -d "{\"properties\":{},\"routing_key\":\"inventory-update-queue\",\"payload\":\"{\\\"itemSku\\\":\\\"$RANDOM_ITEM\\\",\\\"quantityChange\\\":$RANDOM_QTY}\",\"payload_encoding\":\"string\"}" \
    http://localhost:15672/api/exchanges/%2f/amq.default/publish

  sleep 5
done

echo "Finished generating events."
