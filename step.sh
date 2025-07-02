#!/bin/bash

TEMP_RESPONSE="/tmp/jira_response.json"

# --- Split the list of ticket keys using the specified delimiter ---
IFS=$TICKET_DELIMITER read -ra ISSUE_KEYS <<< "$TICKET_LIST"

if [ -z "$IFS" ]; then
    echo "| !!! No tickets found, expected delimiter '$TICKET_DELIMITER' in: $TICKET_LIST"
    exit 1
fi

# --- Create the version in Jira ---
RESPONSE=$(curl -s -w "%{http_code}" -o $TEMP_RESPONSE -X POST \
    -u "$JIRA_USER:$JIRA_TOKEN" \
    -H "Content-Type: application/json" \
    "https://$JIRA_DOMAIN/rest/api/3/version" \
    -d "{
    \"description\": \"$VERSION_DESCRIPTION\",
    \"name\": \"$VERSION_NAME\",
    \"project\": \"$PROJECT_KEY\",
    \"released\": false
    }")

if [ "$RESPONSE" -eq 201 ]; then
    echo "| ✓ Version '$VERSION_NAME' successfully created in project '$PROJECT_KEY'."
    echo "|"
else
    echo "| ⚠️  Failed to create version. HTTP code: $RESPONSE"
    cat $TEMP_RESPONSE
    echo "|"
    echo "|"
fi

# Clean up
rm -f $TEMP_RESPONSE

# --- Update each issue with the new version ---
echo "| Updating issues with version \"$VERSION_NAME\"..."
for ISSUE_KEY in "${ISSUE_KEYS[@]}"; do
    RESPONSE=$(curl -s -w "%{http_code}" -o $TEMP_RESPONSE -X PUT \
    -u "$JIRA_USER:$JIRA_TOKEN" \
    -H "Content-Type: application/json" \
    "https://$JIRA_DOMAIN/rest/api/3/issue/$ISSUE_KEY" \
    -d "{
        \"fields\": {
        \"fixVersions\": [
            { \"name\": \"$VERSION_NAME\" }
        ]
        }
    }")

    if [ "$RESPONSE" == "204" ]; then
    echo "| ✓ $ISSUE_KEY updated successfully"
    else
    echo "| X $ISSUE_KEY update failed (HTTP code: $RESPONSE)"
    cat $TEMP_RESPONSE
    echo "|"
    fi

    # Clean up
    rm -f $TEMP_RESPONSE
done