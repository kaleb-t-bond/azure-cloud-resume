// Azure Function — View Counter (Node.js v1 programming model)
// Route: GET /api/view-counter

const { CosmosClient } = require("@azure/cosmos");

const DATABASE_NAME = "resume-db";
const CONTAINER_NAME = "counters";
const COUNTER_ID = "page-views";

// Lazily initialized — created on the first request, then reused.
// This avoids any startup failure if the environment variable isn't
// resolved at module load time in the SWA managed environment.
let container = null;

function getContainer() {
    if (!container) {
        const client = new CosmosClient(process.env.COSMOS_CONNECTION_STRING);
        container = client.database(DATABASE_NAME).container(CONTAINER_NAME);
    }
    return container;
}

module.exports = async function (context, req) {
    try {
        const cont = getContainer();
        let newCount;

        try {
            const { resource: item } = await cont.item(COUNTER_ID, COUNTER_ID).read();
            newCount = item.count + 1;
            await cont.items.upsert({ id: COUNTER_ID, count: newCount });
        } catch (err) {
            if (err.code === 404) {
                // First-ever visit: create the counter document.
                newCount = 1;
                await cont.items.create({ id: COUNTER_ID, count: newCount });
            } else {
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
