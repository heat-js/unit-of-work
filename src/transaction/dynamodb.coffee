
import crypto from 'crypto'

export default class DynamoDbTransaction

	count: 0
	limit: 25

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

		@mergeUpdateQueries()

		@queries.putItem.forEach (query) ->
			items.push { Put: query }

		@queries.updateItem.forEach (query) ->
			items.push { Update: query }

		@queries.deleteItem.forEach (query) ->
			items.push { Delete: query }

		if not items.length
			return

		return @db.transactWrite {
			TransactItems: items
		}
		.promise()

	mergeUpdateQueries: ->
		updates = {}

		@queries.updateItem.forEach (query) ->
			index = JSON.stringify {
				table: 	query.TableNam
				key:	query.Key
			}

			if not updates[index]
				updates[index] = [query]
			else
				updates[index].push query

		# ---------------------------------------------------------
		# Dirty fix to combine multiple queries on the same index

		@queries.updateItem = new Set

		for index, queries of updates
			baseQuery = queries.shift()

			updateExpression 	= [baseQuery.UpdateExpression]
			conditionExpression = []

			if baseQuery.ConditionExpression
				conditionExpression.push baseQuery.ConditionExpression

			for query, index in queries
				nameMapping = {}
				for oldKey, value of query.ExpressionAttributeNames
					newKey = '#' + crypto.randomBytes(16).toString 'hex'
					query.ExpressionAttributeNames[newKey] = value
					delete query.ExpressionAttributeNames[oldKey]
					nameMapping[oldKey] = newKey

				valueMapping = {}
				for oldKey, value of query.ExpressionAttributeValues
					newKey = ':' + crypto.randomBytes(16).toString 'hex'
					query.ExpressionAttributeValues[newKey] = value
					delete query.ExpressionAttributeValues[oldKey]
					valueMapping[oldKey] = newKey

				if query.UpdateExpression
					query.UpdateExpression = query.UpdateExpression.replace 'SET ', ''

					for oldKey, newKey of nameMapping
						query.UpdateExpression = query.UpdateExpression.replace new RegExp(oldKey, 'g'), newKey

					for oldKey, newKey of valueMapping
						query.UpdateExpression = query.UpdateExpression.replace new RegExp(oldKey, 'g'), newKey

					updateExpression.push query.UpdateExpression

				if query.ConditionExpression
					for oldKey, newKey of nameMapping
						query.ConditionExpression = query.ConditionExpression.replace new RegExp(oldKey, 'g'), newKey

					for oldKey, newKey of valueMapping
						query.ConditionExpression = query.ConditionExpression.replace new RegExp(oldKey, 'g'), newKey

					conditionExpression.push query.ConditionExpression

				Object.assign baseQuery.ExpressionAttributeNames, query.ExpressionAttributeNames
				Object.assign baseQuery.ExpressionAttributeValues, query.ExpressionAttributeValues

			baseQuery.UpdateExpression = updateExpression.join ', '

			if conditionExpression.length
				baseQuery.ConditionExpression = conditionExpression.join ' and '

			@queries.updateItem.add baseQuery
