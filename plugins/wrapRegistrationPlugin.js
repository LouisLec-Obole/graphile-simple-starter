const { makeWrapResolversPlugin } = require("graphile-utils");

module.exports = makeWrapResolversPlugin({
  Mutation: {
    register: {
      async resolve(resolver, _source, {input}, context, _resolveInfo) {
        const newInput = {...input, email: input.email.toLowerCase().replace(/\s+/g,'')}
        console.log('new input', newInput);
        const result = await resolver(_source, {input: newInput}, context, _resolveInfo);
        return result;
      },
    },
  },
});
