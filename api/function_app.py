import azure.functions as func
import os
import json
import logging
from azure.cosmos import CosmosClient, exceptions

# ---------------------------------------------------------------------------
# Module-level Cosmos DB client
#
# WHY AT MODULE LEVEL (outside the function handler)?
#   Azure Functions reuses the same worker process across "warm" invocations.
#   Creating the CosmosClient once here means the TCP connection to Cosmos DB
#   is established on the first request and reused on all subsequent ones,
#   avoiding the overhead of reconnecting on every call.
#   This is a standard performance best practice for serverless functions.
# ---------------------------------------------------------------------------
CONNECTION_STRING = os.environ["COSMOS_CONNECTION_STRING"]
DATABASE_NAME = "resume-db"
CONTAINER_NAME = "counters"
COUNTER_ID = "page-views"

cosmos_client = CosmosClient.from_connection_string(CONNECTION_STRING)
db_client = cosmos_client.get_database_client(DATABASE_NAME)
container_client = db_client.get_container_client(CONTAINER_NAME)

# ---------------------------------------------------------------------------
# Function App entry point (Python v2 programming model)
#
# WHY ANONYMOUS AUTH?
#   AuthLevel.ANONYMOUS means no API key is required in the fetch() URL.
#   This is appropriate for a public view counter — there is no sensitive
#   operation being performed, and keeping the JS simple is a priority.
# ---------------------------------------------------------------------------
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="view-counter", methods=["GET"])
def view_counter(req: func.HttpRequest) -> func.HttpResponse:
    """
    GET /api/view-counter

    Reads the current page-view count from Cosmos DB, increments it by 1,
    persists the new value, and returns it as JSON.

    Cosmos DB document structure:
        { "id": "page-views", "count": <integer> }

    Returns:
        200 OK  ->  { "count": <integer> }
        500     ->  { "error": "<message>" }  (if database is unreachable)
    """
    logging.info("view_counter triggered.")

    try:
        # Read the single counter document.
        # The partition key value matches the document's 'id' field ("/id" path).
        item = container_client.read_item(
            item=COUNTER_ID,
            partition_key=COUNTER_ID
        )
        new_count = item["count"] + 1

    except exceptions.CosmosResourceNotFoundError:
        # First-ever call: the document doesn't exist yet.
        # Self-initialize with count = 1 so no manual database seeding is needed.
        logging.info("Counter document not found — initializing at 1.")
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

    # Persist the incremented count.
    # WHY UPSERT INSTEAD OF REPLACE?
    #   upsert_item creates the document if it doesn't exist, or replaces it if
    #   it does. This makes the write idempotent — safe even if the document was
    #   somehow deleted between the read above and this write.
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

    logging.info(f"View count updated to {new_count}.")
    return func.HttpResponse(
        body=json.dumps({"count": new_count}),
        mimetype="application/json",
        status_code=200
    )
