import express from "express";
import path from "path";
import pg from "pg";
import client from "prom-client";
import { fileURLToPath } from "url";

const { Pool } = pg;
const {
  Counter,
  Histogram,
  Registry,
  collectDefaultMetrics,
} = client;

const app = express();
const port = Number(process.env.PORT || "8080");
const leaderboardLimit = Number(process.env.LEADERBOARD_LIMIT || "10");
const corsOrigin = process.env.CORS_ORIGIN || "*";
const metricsRegistry = new Registry();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const staticDir = path.join(__dirname, "public");

collectDefaultMetrics({ register: metricsRegistry });

const httpRequestCounter = new Counter({
  name: "snake_api_http_requests_total",
  help: "Total number of HTTP requests handled by the snake API.",
  labelNames: ["method", "route", "status_code"],
  registers: [metricsRegistry],
});

const httpRequestDuration = new Histogram({
  name: "snake_api_http_request_duration_seconds",
  help: "Duration of HTTP requests handled by the snake API.",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [metricsRegistry],
});

const scoreSubmissionCounter = new Counter({
  name: "snake_api_score_submissions_total",
  help: "Number of score submissions received by the snake API.",
  labelNames: ["result"],
  registers: [metricsRegistry],
});

const healthcheckCounter = new Counter({
  name: "snake_api_healthcheck_total",
  help: "Number of health check requests by result.",
  labelNames: ["result"],
  registers: [metricsRegistry],
});

const leaderboardRequestCounter = new Counter({
  name: "snake_api_leaderboard_requests_total",
  help: "Number of leaderboard read requests served by the snake API.",
  registers: [metricsRegistry],
});

const scoreRejectionCounter = new Counter({
  name: "snake_api_score_rejections_total",
  help: "Number of rejected score submissions grouped by reason.",
  labelNames: ["reason"],
  registers: [metricsRegistry],
});

const userUpsertCounter = new Counter({
  name: "snake_api_user_upserts_total",
  help: "Number of leaderboard upsert outcomes grouped by result.",
  labelNames: ["result"],
  registers: [metricsRegistry],
});

const dbQueryCounter = new Counter({
  name: "snake_api_db_queries_total",
  help: "Total number of database queries grouped by operation and result.",
  labelNames: ["operation", "result"],
  registers: [metricsRegistry],
});

const dbQueryDuration = new Histogram({
  name: "snake_api_db_query_duration_seconds",
  help: "Duration of database queries grouped by operation.",
  labelNames: ["operation"],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2],
  registers: [metricsRegistry],
});

const dbPoolClientsGauge = new client.Gauge({
  name: "snake_api_db_connection_pool_clients",
  help: "Total number of clients in the PostgreSQL connection pool.",
  registers: [metricsRegistry],
});

const dbPoolIdleGauge = new client.Gauge({
  name: "snake_api_db_connection_pool_idle",
  help: "Number of idle clients in the PostgreSQL connection pool.",
  registers: [metricsRegistry],
});

const dbPoolWaitingGauge = new client.Gauge({
  name: "snake_api_db_connection_pool_waiting",
  help: "Number of requests waiting for a PostgreSQL pool client.",
  registers: [metricsRegistry],
});

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || "5432"),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSLMODE === "require" ? { rejectUnauthorized: false } : false,
});

function updateDbPoolMetrics() {
  dbPoolClientsGauge.set(pool.totalCount);
  dbPoolIdleGauge.set(pool.idleCount);
  dbPoolWaitingGauge.set(pool.waitingCount);
}

async function observeDbQuery(operation, queryFn) {
  const stopTimer = dbQueryDuration.startTimer({ operation });

  try {
    const result = await queryFn();
    dbQueryCounter.inc({ operation, result: "success" });
    return result;
  } catch (error) {
    dbQueryCounter.inc({ operation, result: "error" });
    throw error;
  } finally {
    stopTimer();
    updateDbPoolMetrics();
  }
}

updateDbPoolMetrics();

app.use((request, response, next) => {
  const startedAt = process.hrtime.bigint();

  response.on("finish", () => {
    const route = request.route?.path || request.path || "unknown";
    const statusCode = String(response.statusCode);
    const durationSeconds = Number(process.hrtime.bigint() - startedAt) / 1_000_000_000;

    httpRequestCounter.inc({
      method: request.method,
      route,
      status_code: statusCode,
    });

    httpRequestDuration.observe(
      {
        method: request.method,
        route,
        status_code: statusCode,
      },
      durationSeconds
    );
  });

  next();
});

app.use((request, response, next) => {
  response.setHeader("Access-Control-Allow-Origin", corsOrigin);
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).end();
    return;
  }

  next();
});

app.use(express.json());
app.use(express.static(staticDir));

app.get("/metrics", async (_request, response) => {
  response.set("Content-Type", metricsRegistry.contentType);
  response.end(await metricsRegistry.metrics());
});

async function initDatabase() {
  await observeDbQuery("init_create_scores_table", () => pool.query(`
    CREATE TABLE IF NOT EXISTS scores (
      id BIGSERIAL PRIMARY KEY,
      username VARCHAR(32) NOT NULL UNIQUE,
      highest_score INTEGER NOT NULL CHECK (highest_score >= 0),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `));

  const columnsResult = await observeDbQuery(
    "init_read_columns",
    () => pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'scores'
    `
    )
  );

  const columns = new Set(columnsResult.rows.map((row) => row.column_name));

  if (columns.has("score") && !columns.has("highest_score")) {
    await observeDbQuery("init_rename_score_column", () => pool.query(`
      ALTER TABLE scores
      RENAME COLUMN score TO highest_score
    `));
  }

  if (columns.has("created_at") && !columns.has("updated_at")) {
    await observeDbQuery("init_rename_created_at_column", () => pool.query(`
      ALTER TABLE scores
      RENAME COLUMN created_at TO updated_at
    `));
  }

  await observeDbQuery("init_alter_username_type", () => pool.query(`
    ALTER TABLE scores
    ALTER COLUMN username TYPE VARCHAR(32)
  `));

  await observeDbQuery("init_alter_username_not_null", () => pool.query(`
    ALTER TABLE scores
    ALTER COLUMN username SET NOT NULL
  `));

  await observeDbQuery("init_alter_highest_score_not_null", () => pool.query(`
    ALTER TABLE scores
    ALTER COLUMN highest_score SET NOT NULL
  `));

  await observeDbQuery("init_alter_updated_at_default", () => pool.query(`
    ALTER TABLE scores
    ALTER COLUMN updated_at SET DEFAULT NOW()
  `));

  await observeDbQuery("init_backfill_updated_at", () => pool.query(`
    UPDATE scores
    SET updated_at = NOW()
    WHERE updated_at IS NULL
  `));

  await observeDbQuery("init_alter_updated_at_not_null", () => pool.query(`
    ALTER TABLE scores
    ALTER COLUMN updated_at SET NOT NULL
  `));

  await observeDbQuery("init_add_highest_score_check", () => pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'scores_highest_score_check'
      ) THEN
        ALTER TABLE scores
        ADD CONSTRAINT scores_highest_score_check CHECK (highest_score >= 0);
      END IF;
    END $$;
  `));

  await observeDbQuery("init_add_username_unique", () => pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'scores_username_key'
      ) THEN
        ALTER TABLE scores
        ADD CONSTRAINT scores_username_key UNIQUE (username);
      END IF;
    END $$;
  `));
}

function validatePayload(body) {
  const username = typeof body.username === "string" ? body.username.trim() : "";
  const score = Number(body.score);

  if (!username || username.length > 32) {
    scoreRejectionCounter.inc({ reason: "invalid_username" });
    return { ok: false, message: "username must be between 1 and 32 characters" };
  }

  if (!Number.isInteger(score) || score < 0) {
    scoreRejectionCounter.inc({ reason: "invalid_score" });
    return { ok: false, message: "score must be a non-negative integer" };
  }

  return { ok: true, username, score };
}

app.get("/healthz", async (_request, response) => {
  try {
    await observeDbQuery("healthz", () => pool.query("SELECT 1"));
    healthcheckCounter.inc({ result: "success" });
    response.json({ status: "ok" });
  } catch (error) {
    healthcheckCounter.inc({ result: "error" });
    response.status(503).json({ status: "error", message: "database unavailable" });
  }
});

app.get("/api/scores", async (_request, response) => {
  try {
    const result = await observeDbQuery(
      "leaderboard_select",
      () => pool.query(
      `
        SELECT id, username, highest_score, updated_at
        FROM scores
        ORDER BY highest_score DESC, updated_at ASC
        LIMIT $1
      `,
      [leaderboardLimit]
      )
    );

    leaderboardRequestCounter.inc();
    response.json({ scores: result.rows });
  } catch (error) {
    response.status(500).json({ message: "failed to fetch scores" });
  }
});

app.post("/api/scores", async (request, response) => {
  const validation = validatePayload(request.body);

  if (!validation.ok) {
    scoreSubmissionCounter.inc({ result: "invalid" });
    response.status(400).json({ message: validation.message });
    return;
  }

  try {
    const existingResult = await observeDbQuery(
      "score_lookup_existing",
      () => pool.query(
        `
          SELECT highest_score
          FROM scores
          WHERE username = $1
        `,
        [validation.username]
      )
    );

    const existingRow = existingResult.rows[0];

    const result = await observeDbQuery(
      "score_upsert",
      () => pool.query(
      `
        INSERT INTO scores (username, highest_score)
        VALUES ($1, $2)
        ON CONFLICT (username)
        DO UPDATE
        SET
          highest_score = GREATEST(scores.highest_score, EXCLUDED.highest_score),
          updated_at = CASE
            WHEN EXCLUDED.highest_score > scores.highest_score THEN NOW()
            ELSE scores.updated_at
          END
        RETURNING id, username, highest_score, updated_at
      `,
      [validation.username, validation.score]
      )
    );

    scoreSubmissionCounter.inc({ result: "success" });

    if (!existingRow) {
      userUpsertCounter.inc({ result: "created" });
    } else if (validation.score > existingRow.highest_score) {
      userUpsertCounter.inc({ result: "updated" });
    } else {
      userUpsertCounter.inc({ result: "unchanged" });
    }

    response.status(201).json(result.rows[0]);
  } catch (error) {
    scoreSubmissionCounter.inc({ result: "error" });
    response.status(500).json({ message: "failed to save score" });
  }
});

app.get("/", (_request, response) => {
  response.sendFile(path.join(staticDir, "index.html"));
});

app.get(/^\/(?!api\/|metrics$|healthz$).*/, (_request, response) => {
  response.sendFile(path.join(staticDir, "index.html"));
});

app.use((_request, response) => {
  response.status(404).json({ message: "not found" });
});

initDatabase()
  .then(() => {
    app.listen(port, "0.0.0.0", () => {
      console.log(`snake-api listening on ${port}`);
    });
  })
  .catch((error) => {
    console.error("failed to initialize database", error);
    process.exit(1);
  });
