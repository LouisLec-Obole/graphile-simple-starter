require("dotenv").config();
const express = require("express");
const { postgraphile, makePluginHook } = require("postgraphile");
const { default: PgPubsub } = require("@graphile/pg-pubsub");


const pluginHook = makePluginHook([PgPubsub]);


const app = express();

app.use(
  postgraphile(
    process.env.DATABASE_URL,
    process.env.SCHEMA,
    {
      pluginHook,
      subscriptions: true,
      skipPlugins: [require("graphile-build").NodePlugin],
      appendPlugins: [
        require("./plugins/subscriptionPlugin"),
        require("postgraphile/plugins").TagsFilePlugin,
        require("@graphile-contrib/pg-simplify-inflector"),
        require("postgraphile-plugin-connection-filter"),
      ],
      dynamicJson: true,
      enableCors: true,
      enableQueryBatching: true,
      enhanceGraphiql: true,
      extendedErrors: ["hint", "detail", "errcode"],
      graphiql: process.env.NODE_ENV == "development",
      ignoreIndexes: false,
      ignoreRBAC: false,
      jwtPgTypeIdentifier: "app_public.jwt_token",
      jwtSecret: "SuperSecret!",
      pgDefaultRole: "capi_anon",
      legacyRelations: "omit",
      setofFunctionsContainNulls: false,
      showErrorStack: "json",
      watchPg: process.env.NODE_ENV == "development",
      allowExplain(req) {},
  })
);

app.listen(process.env.PORT, () =>
  console.log("Server listening on port " + process.env.PORT)
);
