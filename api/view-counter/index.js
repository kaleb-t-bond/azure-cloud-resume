// Azure Function — View Counter (Node.js v1 programming model)
// Route: GET /api/view-counter
//
// WHAT THIS DOES:
//   Every time someone visits the resume, their browser calls this function.
//   The function reads the current view count from Cosmos DB, increments it by 1,
//   saves it back, and returns the new count as JSON: { "count": 42 }
//
// WHY NODE.JS?
//   Azure Static Web Apps managed functions are optimized for JavaScript/Node.js.
//   The logic is identical to the Python version — just different syntax.

const { CosmosClient } = require("@azure/cosmos");

const DATABASE_NAME = "resume-db";
const CONTAINER_NAME = "counters";
const COUNTER_ID = "page-views";

// Create the Cosmos DB client once at module load time.
// Azure Functions reuses the same process ("warm instance") across many requests,
// so this client and its connection pool are reused — much faster than reconnecting
// on every single invocation.
const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING);
const container = client.database(DATABASE_NAME).container(CONTAINER_NAME);

module.exports = async function (context, req) {
    try {
        let newCount;

        try {
            // Read the existing counter document from Cosmos DB.
            // The document looks like: { "id": "page-views", "count": 42 }
            // The second argument to .item() is the partition key value (same as the id).
            const { resource: item } = await container.item(COUNTER_ID, COUNTER_ID).read();
            newCount = item.count + 1;

            // Write the updated count back. upsert = insert-or-update, safe to call every time.
            await container.items.upsert({ id: COUNTER_ID, count: newCount });
        } catch (err) {
            if (err.code === 404) {
                // First-ever visit: the counter document doesn't exist yet. Create it.
                newCount = 1;
                await container.items.create({ id: COUNTER_ID, count: newCount });
            } else {
                // Unexpected Cosmos DB error — rethrow to be caught by the outer try/catch.
                throw err;
            }
        }

        context.res = {
            status: 200,
            body: JSON.stringify({ count: newCount }),
            headers: { "Content-Type": "application/json" }
        };
    } catch (err) {
        context.log.error("Cosmos DB error:", err.message);
        context.res = {
            status: 500,
            body: JSON.stringify({ error: "Database error" }),
            headers: { "Content-Type": "application/json" }
        };
    }
};
