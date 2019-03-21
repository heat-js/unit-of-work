
export default class DynamoDbTransaction

	count: 0
	limit: 10

	constructor: (@db) ->
		@queries = {
			putItem: 	new Set
			updateItem: new Set
			deleteItem: new Set
		}

	add: (work) ->
		operation = work.operation
		query     = work.params

		if ++@count > @limit
			throw new Error "Amount of mutations inside a transaction cannot be more than #{@limit}"

		@queries[operation].add query

		return @

	commit: ->
		items = []

		@queries.putItem.forEach (query) ->
			items.push { Put: query }

		@queries.updateItem.forEach (query) ->
			items.push { Update: query }

		@queries.deleteItem.forEach (query) ->
			items.push { Delete: query }

		if not items.length
			return

		return @dynamodb.transactWrite {
			TransactItems: items
		}
		.promise()
