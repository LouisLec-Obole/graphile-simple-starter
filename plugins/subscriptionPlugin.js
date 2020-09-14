const { makeExtendSchemaPlugin, gql, embed } = require("graphile-utils");

const newBoatTopic = (_args, context, _resolveInfo) => {
  if (_args.userId) {
    return `graphql:new_boat:${_args.userId}`
  } else {
    throw new Error("Not a boat...");
  }
};

module.exports = makeExtendSchemaPlugin(({ pgSql: sql }) => ({
  typeDefs: gql`
    type BoatSubscriptionPayload {
      boat: Boat
      event: String
    }
    extend type Subscription {
      """
      Déclanchée à chaques fois qu'on créé un bateau
      """
      newBoatCreated(userId: UUID!): BoatSubscriptionPayload
      @pgSubscription(topic: ${embed(newBoatTopic)})
    }
  `,

  resolvers: {
    BoatSubscriptionPayload: {
      async boat(
        event,
        _args,
        _context,
        { graphile: { selectGraphQLResultFromTable } }
        ) {
        const [row] = await selectGraphQLResultFromTable(
          sql.fragment`app_public.boats`,
          (tableAlias, sqlBuilder) => {
            sqlBuilder.where(
              sql.fragment`${tableAlias}.id = ${sql.value(event.subject)}`
            );
          }
        );
        return row;
      },
    },
  },
}));
