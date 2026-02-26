// Minimal diagnostic function — no dependencies, no Cosmos DB.
// Purpose: confirm that SWA managed functions can deploy at all in this subscription.
// If this deploys successfully, we know the issue is with @azure/cosmos or app settings.
// If this also fails, the issue is at the Azure infrastructure/subscription level.
module.exports = async function (context, req) {
    context.res = {
        status: 200,
        body: JSON.stringify({ count: 0 }),
        headers: { "Content-Type": "application/json" }
    };
};
