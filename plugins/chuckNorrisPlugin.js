const {makeExtendSchemaPlugin, gql}= require("graphile-utils");
const fetch = require("node-fetch");

module.exports = makeExtendSchemaPlugin(()=>({
  typeDefs: gql`
  type ChuckNorrisJoke {
    icon_url: String
    id: String
    url: String
    value: String
  }
  extend type Query {
    getChuckNorrisJoke: ChuckNorrisJoke
  }
  `,

  resolvers: {
    Query: {
      getChuckNorrisJoke: async ()=>{
        return fetch("https://api.chucknorris.io/jokes/random").then(
          result => result.json()
        );
      }
    }
  }
}))

