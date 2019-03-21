

app.factory 'users', (app, transaction) ->
	return new UserRepo app.dynamodb, transaction

app.factory 'books', (app, transaction) ->
	return new BookRepo app.dynamodb, transaction


unit = app.unitOfWork

users = unit.get 'users'
users.add { name: 'Bob' }
users.add { name: 'Alice' }

books = unit.get 'books'
books.add { name: 'Wonder Land' }

await unit.commit()
