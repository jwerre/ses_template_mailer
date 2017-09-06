fs = require("fs")
path = require("path")
should = require("should")
async = require("async")
_ = require("lodash")
Email = require("../src/email")

try
	conf = require('./conf')
	
catch e
	throw new Error("Must have conf.coffee in test directory, run `cp test/conf.sample.coffee conf.coffee`")


describe "Email", ->

	credentials = null

	options =
		Destination:
			BccAddresses: null
			CcAddresses: null
			ToAddresses: null

		Message:
			Subject:
				Data: "Test Email"
			Body:
				Html:
					Data: "<p><em>This</em> is a plain old <strong>HTML</strong> message.</p>"
				Text:
					Data: "This is a plain old text message"
			TemplateData: null
			TemplateType: null

		Source: null
		ReplyToAddresses: null
		ReturnPath: null


	if conf
		credentials = conf.credentials
		options.Source = conf.from
		options.Destination.ToAddresses = conf.to
		options.Message.TemplateData = conf.templateData

	it 'should the correct template type', ->
		email = new Email(options, credentials)
		should(email._getTemplateType(null)).equal( Email.TEMPLATE_LANGUGES[0] )
		should(email._getTemplateType('handlbars')).equal( Email.TEMPLATE_LANGUGES[0] )
		should(email._getTemplateType('pug')).equal( Email.TEMPLATE_LANGUGES[1] )
		should(email._getTemplateType('ejs')).equal( Email.TEMPLATE_LANGUGES[2] )
		should(email._getTemplateType('underscore')).equal( Email.TEMPLATE_LANGUGES[3] )
		should(email._getTemplateType("https://zyz.com/my-template.invalid")).equal( Email.TEMPLATE_LANGUGES[0] )
		should(email._getTemplateType("https://zyz.com/my-template.handlebars")).equal( Email.TEMPLATE_LANGUGES[0] )
		should(email._getTemplateType("https://zyz.com/my-template.pug")).equal( Email.TEMPLATE_LANGUGES[1] )
		should(email._getTemplateType("https://zyz.com/my-template.ejs")).equal( Email.TEMPLATE_LANGUGES[2] )
		should(email._getTemplateType("https://zyz.com/my-template.underscore")).equal( Email.TEMPLATE_LANGUGES[3] )

	it "should error because there is no 'Destination'", (done) ->
		opts = _.cloneDeep(options)
		opts.Destination.ToAddresses = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because there is no 'Source'", (done) ->
		opts = _.cloneDeep(options)
		opts.Source = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because there is no 'Message'", (done) ->
		opts = _.cloneDeep(options)
		opts.Message = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because there is no 'Message.Subject'", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Subject.Data = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because there is no 'Message.Body'", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Body = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()


	it "should error because there is no 'Message.Body.Html.Data'", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Body.Html.Data = null
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because template location could not be found", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Body.Html.Data = "https://zyz.com/not-found.underscore"
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should error because a pug text template was provided", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.TemplateType = 'pug'
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.exist(err)
			should.not.exist(result)
			done()

	it "should send a plain email", (done) ->
		opts = _.cloneDeep(options)
		email = new Email(opts, credentials)
		email.send (err, result) ->
			should.not.exist(err)
			done()

	it "should send an HTML email and create a text email from html", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Body.Text = null
		email = new Email(opts, credentials)
		email.send (err, result, data) ->
			should.not.exist(err)
			should.exist(result)
			(opts.Message.Body.Text.Data.length).should.be.above(10)
			(opts.Message.Body.Text.Data).should.not.match(/<[a-z][\s\S]*>/)
			should.exist(result.ResponseMetadata)
			should.exist(result.ResponseMetadata.RequestId)
			done()

	it "should retrieve html template from url", (done) ->
		opts = _.cloneDeep(options)
		opts.Message.Body.Html.Data = "https://surveyplanet.com"
		email = new Email(opts, credentials)
		email.send (err, result, data) ->
			should.not.exist(err)
			should.exist(result)
			should.exist(result.ResponseMetadata)
			should.exist(result.ResponseMetadata.RequestId)
			done()


	it "should send multiple emails", (done) ->
		opts = _.cloneDeep(options)
		# set global template data
		template = opts.Message.Body.Html.Data
		templateData = opts.Message.templateData
		opts.Message.Body.Html.Data = null
		opts.Message.templateData = null
		
		multipleOpts = []
		[1..2].forEach (i) ->
			multipleOpts.push( _.cloneDeep(options) )
			
		email = new Email(multipleOpts, credentials)
		email.template = template
		email.templateData = templateData
		email.send (err, result, data) ->
			should.not.exist(err)
			should.exist(result)
			result.should.be.an.Array()
			result.should.have.length(multipleOpts.length)
			result[0].should.have.property('MessageId')
			result[0].should.have.property('ResponseMetadata')
			result[0].ResponseMetadata.should.have.property('RequestId')

			data.should.be.an.Array()
			data.should.have.length(multipleOpts.length)
			data[0].should.deepEqual(multipleOpts[0])
			done()

	it "should send multiple emails and return events", (done) ->
		opts = _.cloneDeep(options)
		multipleOpts = []
		[1..3].forEach (i) ->
			multipleOpts.push( _.cloneDeep(options) )
			
		email = new Email(multipleOpts, credentials)
		email.on Email.COMPLETE_EVENT, (errs, results, data) ->
			should.not.exist(errs)
			should.exist(results)
			results.should.be.an.Array()
			results.should.have.length(multipleOpts.length)
			results[0].should.have.property('MessageId')
			results[0].should.have.property('ResponseMetadata')
			results[0].ResponseMetadata.should.have.property('RequestId')
			
			data.should.be.an.Array()
			data.should.have.length(multipleOpts.length)
			data[0].should.deepEqual(multipleOpts[0])

			done()

		email.on Email.SEND_EVENT, (result) ->
			should.exist(result)
			
		email.on Email.ERROR_EVENT, (err) ->
			should.not.exist(err)
			
			
		email.send()


	describe "Handlebars", ->
		
		it "should send Handlebars template", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Handlebars Email Template Test'
			opts.Message.Body.Html.Data = conf.templates.handlbars.html
			opts.Message.Body.Text.Data = conf.templates.handlbars.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()

		it "should send Handlebars template form uri", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Handlebars Email Template form URI Test'
			opts.Message.Body.Html.Data = conf.templateUris.handlbars.html
			opts.Message.Body.Text.Data = conf.templateUris.handlbars.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()


	# PUG
	describe "Pug", ->

		it "should not send Pug template since pug cannot parse plain text", (done) ->
			opts = _.cloneDeep(options)
			opts.Message.Subject.Data = 'Pug Email Template Test'
			opts.Message.TemplateType = 'pug'
			opts.Message.Body.Html.Data = conf.templates.pug.html
			opts.Message.Body.Text.Data = conf.templates.pug.text
			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.exist(err)
				should.not.exist(result)
				done()

		it "should send Pug template", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Pug Email Template Test'
			opts.Message.TemplateType = 'pug'
			opts.Message.Body.Html.Data = conf.templates.pug.html
			opts.Message.Body.Text.Data = null
			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()

		it "should send Pug template from uri", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Pug Email Template from URI Test'
			opts.Message.Body.Html.Data = conf.templateUris.pug.html
			opts.Message.Body.Text.Data = null
			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()



	#EJS
	describe 'EJS', ->

		it "should send EJS template", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'EJS Email Template Test'
			opts.Message.TemplateType = 'ejs'
			opts.Message.Body.Html.Data = conf.templates.ejs.html
			opts.Message.Body.Text.Data = conf.templates.ejs.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()

		it "should send EJS template from uri", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'EJS Email Template from URI Test'
			opts.Message.Body.Html.Data = conf.templateUris.ejs.html
			opts.Message.Body.Text.Data = conf.templateUris.ejs.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()



	#UNDERSCORE
	describe "Underscore", ->

		it "should send Underscore template", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Underscore Email Template Test'
			opts.Message.TemplateType = 'underscore'
			opts.Message.Body.Html.Data = conf.templates.underscore.html
			opts.Message.Body.Text.Data = conf.templates.underscore.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()

		it "should send Underscore template from uri", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Underscore Email Template from URI Test'
			opts.Message.Body.Html.Data = conf.templateUris.underscore.html
			opts.Message.Body.Text.Data = conf.templateUris.underscore.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()

		it "should send Underscore template from uri", (done) ->
			opts = _.cloneDeep(options)

			opts.Message.Subject.Data = 'Underscore Email Template from URI Test'
			opts.Message.Body.Html.Data = conf.templateUris.underscore.generic
			opts.Message.TemplateType = 'underscore'
			# opts.Message.Body.Text.Data = conf.templateUris.underscore.text

			email = new Email(opts, credentials)
			email.send (err, result) ->
				should.not.exist(err)
				should.exist(result)
				should.exist(result.ResponseMetadata)
				should.exist(result.ResponseMetadata.RequestId)
				done()
	
	
	
	
