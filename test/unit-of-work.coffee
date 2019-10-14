
import Provider			from '../src/provider/dynamodb'
import Container 		from '@heat/container'
import { startDynamo } 	from '@heat/test'
import crypto 			from 'crypto'

describe 'Test Unit of Work', ->

	# ---------------------------------------------------------
	# Start a DynamoDB instance

	dynamo = startDynamo {
		path: './aws/dynamodb.yml'
	}

	# ---------------------------------------------------------
	# Create the app container

	app = Container.proxy()
	(new Provider).handle app
	app.value 'dynamodb', dynamo.documentClient()

	# ---------------------------------------------------------
	# Create repositories

	Repository = class Repository
		constructor: (@table, @db, @transaction) ->
		get: (id) ->
			result = await @db.get {
				TableName: @table
				Key: {
					id
				}
			}
			.promise()
			return result.Item
		set: (id, key, value) ->
			query = @db.update {
				TableName: @table
				Key: {
					id
				}
				UpdateExpression: 'SET #key = :value'
				ExpressionAttributeNames: { '#key': key }
				ExpressionAttributeValues: { ':value': value }
			}
			@transaction.add query
			return @
		add: (params) ->
			query = @db.put {
				TableName: @table
				Item: {
					...params
				}
			}
			@transaction.add query
			return @

	app.factory 'users', (app, transaction) ->
		return new Repository 'users', app.dynamodb, transaction

	app.factory 'books', (app, transaction) ->
		return new Repository 'books', app.dynamodb, transaction

	bookId = crypto.randomBytes(16).toString 'hex'

	it 'should add multiple items in multiple tables', ->
		unit = app.unitOfWork

		users = unit.get 'users'
		users.add { id: crypto.randomBytes(16).toString('hex'), name: 'Bob' }
		users.add { id: crypto.randomBytes(16).toString('hex'), name: 'Alice' }

		books = unit.get 'books'
		books.add { id: bookId, name: 'Wonder Land' }

		await unit.commit()

	it 'should be able to update with multiple queries on one item', ->
		unit  = app.unitOfWork
		books = unit.get 'books'
		books.set bookId, 'author', 'Lewis Carroll'
		books.set bookId, 'publshedAt', '1865'
		await unit.commit()

		book = await books.get bookId

		expect book.author
			.toBe 'Lewis Carroll'

		expect book.publshedAt
			.toBe '1865'
