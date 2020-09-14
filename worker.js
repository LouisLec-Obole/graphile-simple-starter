require("dotenv").config()
const { run } = require("graphile-worker");

async function main() {
  // Run a worker to execute jobs:
  const runner = await run({
    connectionString: process.env.DATABASE_URL,
    concurrency: 5,
    // Install signal handlers for graceful shutdown on SIGINT, SIGTERM, etc
    noHandleSignals: false,
    pollInterval: 1000,
    taskDirectory: `${__dirname}/tasks`,
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
