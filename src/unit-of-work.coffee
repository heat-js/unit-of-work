
export default class UnitOfWork

	constructor: (@factory, @transaction) ->
		@repositories = new Map

	get: (name) ->
		repo = @repositories.get name

		if not repo
			repo = @factory name, @transaction
			@repositories.set name, repo

		return repo

	commit: ->
		return @transaction.commit()
