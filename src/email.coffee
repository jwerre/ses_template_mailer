EventEmitter = require('events')
path = require('path')
AWS = require('aws-sdk')
_ = require('lodash')
Handlebars = require("handlebars")
pug = require("pug")
ejs = require("ejs")
isUrl = require('is-url')
request = require('request')
async = require('async')
htmlToText = require('html-to-text')

###*
Template Engine for Amazon Web Services Simple Email Service (SES).


@class Email
@constructor
@param Object data SES.sendEmail data. http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SES.html#sendEmail-property
@param Object credentials aws credentials. http://docs.aws.amazon.com/AWSJavaScriptSDK/guide/node-configuring.html
@example
	Email = require('../lib/email')
	email = new Email({

			Destination: {
				BccAddresses: ['Jack Sprat <jack-sprat@hotmail.com>'],
				CcAddresses: ['Humpty Dumpty <humpty-dumpty@yahoo.com>'],
				ToAddresses: ['Peter Pumpkineater <peter-pumpkineater@gmail.com>']
			},
			Message: {
				Subject: {
					Data: 'Pumpkin Eater'
				},
				Body: {
						Html: {
							Data: '<div>{{peter}}, {{peter}} pumpkin eater, Had a wife but couldn't keep her; <a href="{{more}}">more</a></div>'
						},
						Text: {
							Data: '{{peter}}, {{peter}} pumpkin eater, Had a wife but couldn't keep her;'
						}
				},
				TemplateData: {name:'Peter', more: 'https://en.wikipedia.org/wiki/Peter_Peter_Pumpkin_Eater'},
				TemplateType: 'handlebars'
			},
			Source: 'admin@example.com',
			ReplyToAddresses: [ 'Nobody <no-reply@example.com>'],
			ReturnPath: 'admin@example.com'
		}, {
			accessKeyId: 'my_aws_access_key',
			secretAccessKey: 'my_aws_secret_key',
			region: 'us-west-1'
	});

	email.send(params, function(err, data) {
		if (err)
			console.log(err, err.stack); // an error occurred
		else
			console.log(data);		   // successful response
	});


###
class Email extends EventEmitter
	
	
	@COMPLETE_EVENT: 'complete'
	
	@SEND_EVENT: 'send'
	
	@ERROR_EVENT: 'error'

	@TEMPLATE_LANGUGES: [
		"handlebars" # default
		"pug"
		"ejs"
		"underscore"
	]

	###*
	SES rate limit. The amount of emails to send per second

	@property rateLimit
	@type AWS.SES
	@default 90
	###	
	rateLimit: 90


	###*
	Set a global template for multiple recipients.
	This should be a location of a template file or a template string.
	Template files can have the following with extensions
	.pug, .handlebars, .underscore, or .ejs which will determine the
	template language used. If a string is used then Handlebars will be
	used by default unless TemplateType is defined.

	@property template
	@type String
	@default null
	@example
		'https://mybucket.s3.amazonaws.com/template.handlebars'
		## or ##
		'<div class="entry">
			<h1>{{title}}</h1>
			<div class="body">{{body}}</div>
		</div>'
	###
	template: null


	###*
	Object containing the data for the template.

	@property templateData
	@type Object
	@default null
	@example
		{ var1: "var1 content", var2: "var2 content" }
	###
	templateData: null

	###*
	The type of template language to use, either:
	handlebars, pug, ejs, or underscore. "handlebars" is used by default
	unless otherwise specified by extension used by the template name.

	@property template
	@type String
	@default 'handlebars'
	###
	templateType: null

	###*
	Config data for SES

	@property data
	@type Object
	@default null
	###
	data: null

	_ses: null

	constructor: (data, credentials) ->
		
		if not _.isArray(data)
			data = [data]

		@data = data.map (item) ->
			_.defaultsDeep item,
				Destination:
					BccAddresses: null
					CcAddresses: null
					ToAddresses: null

				Message:
					Subject: null
					Body:
						Html:
							Data: null
						Text:
							Data: null
					TemplateData: {}
					TemplateType: 'handlebars'

				Source: null
				ReplyToAddresses: null
				ReturnPath: null

		if credentials
			credentials = _.defaults credentials,
				region: 'us-west-2'

			AWS.config.update(credentials)

		@_ses = new AWS.SES()

	
	###*
	Send an email.
	@method send
	@async
	@param {Function} callback callback function
	###
	send: (callback) ->
		
		if not @data or not @data.length
			err = new Error("data is required")
			
			if _.isFunction(callback)
				return callback(err)
			else
				return @emit(Email.ERROR_EVENT, err)

		
		if @data.length > 1
			
			errCache = []
			resultCache = []
			
			cargo = async.cargo (tasks, done) =>
					
					# delay 1 second
					setTimeout  =>

						async.each tasks, (item, callback) =>
							
								@_dispatch item, (err, result) =>
									
									if err
										errCache.push(err)
										@emit(Email.ERROR_EVENT, err)
										
									else
										resultCache.push(result)
										@emit(Email.SEND_EVENT, result, item)

									callback(null, true)

							, done

					, 1000

				, @rateLimit
			
			cargo.drain = =>
				
				if errCache.length
					err = errCache
					
				if _.isFunction(callback)
					callback(err, resultCache, @data)

				else
					@emit(Email.COMPLETE_EVENT, err, resultCache, @data)
			
			cargo.push(@data)

		
		else
			@_dispatch @data[0], (err, result) =>
				
				if _.isFunction(callback)
					callback(err, result, @data[0])
					
				else

					if err
						@emit(Email.ERROR_EVENT, err)
						err = [err]
					else
						@emit(Email.SEND_EVENT, result, @data[0])

					@emit(Email.COMPLETE_EVENT, err, [result], @data)

		

	_dispatch: ( data, callback ) ->

		if not data
			return callback(new Error("data is required"))

		if not data.Destination or not data.Destination.ToAddresses
			return callback(new Error("Destination is required"))

		if not data.Source
			return callback(new Error("Source is required"))

		if not data.Message
			return callback(new Error("Message is required"))

		if not data.Message.Subject or not data.Message.Subject.Data or not data.Message.Subject.Data.length
			return callback(new Error("Message.Subject is required"))
		
		if not data.Message.Body
			return callback(new Error("Message.Body is required"))

		# console.log require('util').inspect data, {depth:10, colors:true}
		@_prepTemplate data, (err, result) =>
			# console.log require('util').inspect result, {depth:10, colors:true}
			if err
				return callback(err)
			
			if not result
				callback(new Error('Unable to parse options'))

			delete result.Message.TemplateType
			delete result.Message.TemplateData
			@_ses.sendEmail(result, callback)
			
		
	
	_prepTemplate: (data, callback) ->
		
		# console.log "_prepTemplate"
		# console.log require('util').inspect data, {depth:10, colors:true}

		if @template
			data.Message.Body.Html.Data = @template


		if @templateData
			data.Message.TemplateData = @templateData
		
		# get the template type
		type = _.get(data, ['Message', 'TemplateType']) or _.get(data, ['Message','Body','Html','Data'])
		# set which kind of template to use
		data.Message.TemplateType = @_getTemplateType(type)
		
		# make sure there is now plain text emails if pug is the template type
		if 	data.Message.Body.Text and 
			data.Message.Body.Text.Data and 
			data.Message.Body.Text.Data.length and
			data.Message.TemplateType is 'pug'
				return callback(new Error('Plain text emails cannot be compiled with Pug. Set "Message.Body.Text" to "null" to allow the text email to be generated from the HTML.'))

		# if plain text email isn't set set html
		if 	data.Message.Body.Html and 
			data.Message.Body.Html.Data and 
			not data.Message.Body.Text or 
			not data.Message.Body.Text.Data
				data.Message.Body.Text =
					Data: data.Message.Body.Html.Data
		
		# create the template function
		if data.Message and data.Message.TemplateType
			templateMethod = @["_prep#{data.Message.TemplateType.charAt(0).toUpperCase() + data.Message.TemplateType.slice(1)}Template"]

		if _.isFunction(templateMethod)

			
			@_getTemplateString data.Message.Body.Html.Data, data.Message.Body.Text.Data, (err, result) =>
				
				return callback(err) if err

				# just send the email if there is no template data
				# return callback() if not data.Message.TemplateData

				async.parallel [
					(callback) =>
						if result.html
							templateMethod result.html, data.Message.TemplateData, (err, html) ->
								callback(err, html)
						else
							callback(null, data.Message.Body.Html.Data)

					(callback) =>
						if result.text# and data.Message.TemplateType isnt 'pug'
							templateMethod result.text, data.Message.TemplateData, (err, text) ->
								callback(err, text)
						else
							callback(null, data.Message.Body.Text.Data)

				], (err, result) =>

					data.Message.Body.Html.Data = result[0]
					data.Message.Body.Text.Data = result[1]

					# strip html if exists on text
					if /<[a-z][\s\S]*>/.test(data.Message.Body.Text.Data)
						data.Message.Body.Text.Data = htmlToText.fromString(data.Message.Body.Text.Data)
					
					callback(err, data)

		else
			callback(new Error("Unable to define resolve template language #{data.Message.TemplateType}"))

	###*
	Retrieves the template as a string if a url is given.

	@method _getTemplateString
	@param {Function} callback callback function
	@async
	###
	_getTemplateString: (html, text, callback) ->
		
		if not html or not html.length
			return callback(new Error("Must provide an html template"))

		if not text or not text.length
			return callback(new Error("Must provide an text template"))

		async.parallel [
			(callback) =>
				if isUrl(html)
					
					request html, (err, response, body) =>
						if not err and response.statusCode is 200
							callback(null, body)
						else
							callback(new Error("Unable location template at #{html}"))

				else
					callback(null, html)

			(callback) =>

				if isUrl(text)
					
					request text, (err, response, body) =>
						if not err and response.statusCode is 200
							callback(null, body)
						else
							callback(new Error("Unable location template at #{text}"))

				else
					callback(null, text)

		], (err, result) ->
			callback(err, {html:result[0], text:result[1]})


	###*
	Retrieves the template language by first looking looking at the extension
	if a template url if given, then at this.templateType and finally default
	to 'handlebars'.

	@method _getTemplateType
	@param {String} url url of template
	###
	_getTemplateType: (type) ->

		# check type is a url with an extension
		if isUrl(type)

			ext = path.extname(type).replace(".", "")

			if ext and Email.TEMPLATE_LANGUGES.indexOf(ext) > -1
				return ext

		# check if type is defined
		if Email.TEMPLATE_LANGUGES.indexOf(type) > -1
			return type

		# check if templateType is defined
		if @templateType and 
			Email.TEMPLATE_LANGUGES.indexOf(@templateType) > -1
				return @templateType

		# default to handlebars
		Email.TEMPLATE_LANGUGES[0]


	###*
	Parses an html email template.

	@method _prepUnderscoreTemplate
	@param {String} template the template file content
	@param {Function} callback callback function
	@async
	###
	_prepUnderscoreTemplate: (template, data, callback) ->

		try
			templ = _.template(template)
			html = templ( data )
		catch err
			return callback(err)

		callback(null, html)


	###*
	Parses a pug email template.

	@method _prepPugTemplate
	@param {String} template the template file content
	@param {Function} callback callback function
	@async
	###
	_prepPugTemplate: (template, data, callback) ->

		try
			templ = pug.compile(template)
			html = templ(data)
		catch err
			return callback(err)

		callback(null, html)

	###*
	Parses a embedded javaScript templates email template.

	@method _prepEjsTemplate
	@param {String} template the template file content
	@param {Function} callback callback function
	@async
	###
	_prepEjsTemplate: (template, data, callback) ->

		try
			html = ejs.render(template, data)
		catch err
			return callback(err)

		callback(null, html)


	###*
	Parses a handlebars email template.

	@method _prepHandlebarsTemplate
	@param {String} template the template file content
	@param {Function} callback callback function
	@async
	###
	_prepHandlebarsTemplate: (template, data, callback) ->

		try
			templ = Handlebars.compile(template)
			html = templ(data)
		catch err
			return callback(err)

		callback(null, html)



module.exports = Email
