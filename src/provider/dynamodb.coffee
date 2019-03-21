
import Transaction 	from '../transaction/dynamodb'
import UnitOfWork	from '../unit-of-work'
import AWS 			from 'aws-sdk'

export default class Provider

	constructor: (@apiVersion = '2012-08-10') ->

	handle: (app) ->

		app.dynamodb = ->
			return new AWS.DynamoDB.DocumentClient {
				apiVersion: @apiVersion
			}

		app.factory 'dbTransaction', ->
			return new Transaction app.dynamodb

		app.factory 'unitOfWork', ->
			return new UnitOfWork(
				(name, transaction) ->
					return app.get name, transaction

				app.dbTransaction
			)
