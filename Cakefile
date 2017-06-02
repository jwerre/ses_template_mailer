fs = require('fs')
path = require('path')
{spawn}  = require('child_process')

X_PATH = "./node_modules/.bin/"

option '-w', '--watch', 'watch for changes'

task 'scripts', "compile all coffee-script to javascript", (options) ->
	_compileScripts(options.watch)


_compileScripts = (watch=false) ->

	#compile lib
	dest = path.resolve( __dirname, "lib" )
	src = path.resolve( __dirname, 'src' )

	options = ['-b', '-o', dest, '-c', src]
	options.unshift('-w') if watch
	
	console.log options

	coffee = spawn(X_PATH+'coffee', options)

	coffee.stderr.on 'data', (err) ->
		console.error err.toString()

	coffee.stdout.on 'data', (data) ->
		console.log data.toString().trim()

	coffee.on 'exit', (code) ->
		process.exit()
