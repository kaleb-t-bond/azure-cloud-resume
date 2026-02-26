import logging
import json
import os
import azure.functions as func
from azure.cosmos import CosmosClient, exceptions

# Read the Cosmos DB connection string from the environment.
# In Azure, this is set as an app setting on the Static Web App resource (via Terraform).
# Locally, you'd put it in api/local.settings.json (which is gitignored).
CONNECTION_STRING = os.environ["COSMOS_CONNECTION_STRING"]
DATABASE_NAME = "resume-db"
CONTAINER_NAME = "counters"
COUNTER_ID = "page-views"

# Create the Cosmos DB client once at module load time.
# Azure Functions reuses the same process ("warm instance") across many invocations,
# so creating the client here means we reuse the connection pool instead of reconnecting
# on every single request — much faster.
cosmos_client = CosmosClient.from_connection_string(CONNECTION_STRING)
db_client = cosmos_client.get_database_client(DATABASE_NAME)
container_client = db_client.get_container_client(CONTAINER_NAME)


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP-triggered Azure Function (v1 programming model).
    Called by the resume website to read and increment the page view counter.
    Route: GET /api/view-counter
    """
    # Try to read the existing counter document from Cosmos DB.
    # The document has the shape: { "id": "page-views", "count": <number> }
    try:
        item = container_client.read_item(item=COUNTER_ID, partition_key=COUNTER_ID)
        new_count = item["count"] + 1
    except exceptions.CosmosResourceNotFoundError:
        # First-ever visit: the document doesn't exist yet.
        # Create it with count = 1 and return immediately.
        new_count = 1
        container_client.create_item(body={"id": COUNTER_ID, "count": new_count})
        return func.HttpResponse(
            body=json.dumps({"count": new_count}),
            mimetype="application/json",
            status_code=200
        )
    except Exception as e:
        logging.error(f"Cosmos DB read error: {e}")
        return func.HttpResponse(
            body=json.dumps({"error": "Database error"}),
            mimetype="application/json",
            status_code=500
        )

    # Save the incremented count back to Cosmos DB.
    # upsert_item: inserts if missing, updates if present — safe to call every time.
    item["count"] = new_count
    try:
        container_client.upsert_item(body=item)
    except Exception as e:
        logging.error(f"Cosmos DB write error: {e}")
        return func.HttpResponse(
            body=json.dumps({"error": "Failed to save count"}),
            mimetype="application/json",
            status_code=500
        )

    return func.HttpResponse(
        body=json.dumps({"count": new_count}),
        mimetype="application/json",
        status_code=200
    )
