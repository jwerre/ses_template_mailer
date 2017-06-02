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
@param Object options SES.sendEmail options. http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SES.html#sendEmail-property
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
class Email

	@TEMPLATE_LANGUGES: [
		"handlebars" # default
		"pug"
		"ejs"
		"underscore"
	]

	###*
	SES instance

	@property ses
	@type AWS.SES
	@default null
	###
	ses: null

	###*
	Config options for SES

	@property options
	@type Object
	@default null
	###
	options: null

	###*
	Location of a template file or a template string.
	Template files can have the following with extensions
	.pug, .handlebars, .underscore, or .ejs will determine which
	template language to use. If a sting is used then Handlebars will be
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


	constructor: (opts, credentials) ->

		@options = _.defaultsDeep opts,
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

		@ses = new AWS.SES()


	###*
	Send an email.
	@method send
	@async
	@param {Function} callback callback function
	###
	send: ( callback ) ->

		if not @options
			return callback(new TypeError("options are required"))

		if not @options.Destination or not @options.Destination.ToAddresses
			return callback(new TypeError("Destination is required"))

		if not @options.Source
			return callback(new TypeError("Source is required"))

		if not @options.Message
			return callback(new TypeError("Message is required"))

		if not @options.Message.Subject or not @options.Message.Subject.Data or not @options.Message.Subject.Data.length
			return callback(new TypeError("Message.Subject is required"))

		if not @options.Message.Body
			return callback(new TypeError("Message.Body is required"))


		@_prepTemplate (err) =>
			# console.log require('util').inspect @options, {depth:10, colors:true}
			return callback(err) if err
			delete @options.Message.TemplateType
			delete @options.Message.TemplateData
			@ses.sendEmail(@options, callback)


	###*
	Parses template string or uri.

	@method _prepTemplate
	@param {Function} callback callback function
	@async
	###
	_prepTemplate: (callback) ->

		if @template
			@options.Message.Body.Html.Data = @template


		@options.Message.TemplateData = @templateData if @templateData
		@options.Message.TemplateType = @_getTemplateType(@options.Message.Body.Html.Data)

		if @options.Message.Body.Text and @options.Message.Body.Text.Data and @options.Message.Body.Text.Data.length
			if @options.Message.TemplateType is 'pug' or @templateType is 'pug'
				return callback(new TypeError('Plain text emails cannot be compiled with Pug. Set "Message.Body.Text" to "null" to allow the text email to be generated from the HTML.'))

		if @options.Message.Body.Html and @options.Message.Body.Html.Data and ( not @options.Message.Body.Text or not @options.Message.Body.Text.Data)
			@options.Message.Body.Text =
				Data: @options.Message.Body.Html.Data


		templateMethod = @["_prep#{@options.Message.TemplateType.charAt(0).toUpperCase() + @options.Message.TemplateType.slice(1)}Template"]

		if _.isFunction(templateMethod)

			@_getTemplateString (err, result) =>
				return callback(err) if err

				# just send the email if there is no template data
				# return callback() if not @options.Message.TemplateData


				async.parallel [
					(callback) =>
						if result.html
							templateMethod result.html, @options.Message.TemplateData, (err, html) ->
								callback(err, html)
						else
							callback(null, @options.Message.Body.Html.Data)

					(callback) =>
						if result.text# and @options.Message.TemplateType isnt 'pug'
							templateMethod result.text, @options.Message.TemplateData, (err, text) ->
								callback(err, text)
						else
							callback(null, @options.Message.Body.Text.Data)

				], (err, data) =>
					@options.Message.Body.Html.Data = data[0]
					@options.Message.Body.Text.Data = data[1]

					# strip html if exists on text
					if /<[a-z][\s\S]*>/.test(@options.Message.Body.Text.Data)
						@options.Message.Body.Text.Data = htmlToText.fromString(@options.Message.Body.Text.Data)

					callback(err)

		else
			callback(new TypeError("Unable to define resolve template language #{@options.Message.TemplateType}"))

	###*
	Retrieves the template as a string if a url is given.

	@method _getTemplateString
	@param {Function} callback callback function
	@async
	###
	_getTemplateString: (callback) ->

		async.parallel [
			(callback) =>
				if @options.Message.Body.Html and isUrl(@options.Message.Body.Html.Data)
					request @options.Message.Body.Html.Data, (err, response, body) =>
						if not err and response.statusCode == 200
							callback(null, body)
						else
							callback(new TypeError("Unable location template at #{@options.Message.Body.Html.Data}"))

				else
					callback(null, @options.Message.Body.Html.Data)

			(callback) =>

				if @options.Message.Body.Text and isUrl(@options.Message.Body.Text.Data)
					request @options.Message.Body.Text.Data, (err, response, body) =>
						if not err and response.statusCode == 200
							callback(null, body)
						else
							callback(new TypeError("Unable location template at #{@options.Message.Body.Text.Data}"))

				else
					callback(null, @options.Message.Body.Text.Data)

		], (err, result) ->
			callback(err, {html:result[0], text:result[1]})


	###*
	Retrieves the template language by first looking looking at the extension
	if a template url if given, then at this.templateType and finally defaults
	to 'handlebars'.

	@method _getTemplateType
	@param {String} url url of template
	###
	_getTemplateType: (url) ->


		# check if there is an template extension of template file
		if isUrl(url)

			ext = path.extname(url).replace(".", "")

			if ext and Email.TEMPLATE_LANGUGES.indexOf(ext) > -1
				return ext

		# check if templateType is defined
		if @options.Message.TemplateType and Email.TEMPLATE_LANGUGES.indexOf(@options.Message.TemplateType) > -1
			return @options.Message.TemplateType

		# check if templateType is defined
		if @templateType and Email.TEMPLATE_LANGUGES.indexOf(@templateType) > -1
			return @templateType

		# default to handlebars
		else
			return Email.TEMPLATE_LANGUGES[0]


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
