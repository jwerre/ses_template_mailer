# AWS Simple Email Service (SES) Template Mailer

Send HTML or plain text templates through Amazon Web Services Simple Email Service (SES) using Handlebars, Jade, EJS or Underscore.

## Install

	npm install --save ses-template-mailer

## Usage

	Email = require('ses-template-mailer')
	email = new Email(options, aws_credentials);
	email.send(function(error, result){});


## Config

Config options are the the same as [AWS Config](http://docs.aws.amazon.com/AWSJavaScriptSDK/guide/node-configuring.html). If you've already set up your conf globally you can leave this `null`


## Options

Options are the same as [AWS SES sendMail](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SES.html#sendEmail-property) with the following additions.

### Message.TemplateData [Object]

The data to parse the template with. This can also be set with `email.templateData` before calling send.

### Message.TemplateType [String]

The template engine to use. Must be one of the following: "handlebars", "jade", "ejs", "underscore". Handlebars is the default. This can also be set with `email.templateType` before calling send.

### Templates [String]

Templates should be passed in as `Message.Body.Html` and/or `Message.Body.Text` and should either be template text or a valid uri eg: `https://mybucket.s3.amazonaws.com/template.handlebars`. Using an extension name like "handlebars", "jade", "ejs" or "underscore" will overwrite `TemplateType`. If `Message.Body.Text` is `null` then a plain text email will be generated from the HTML. Templates can also be set with `email.template` before calling send. *Note: Since Jade cannot parse pain text emails text is automatically parsed from html, be sure and nullify text property (`Message.Body.Text=null`) if you're using Jade.*


### Example:

	Email = require('../lib/email')
	email = new Email(
		{
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
		}

	);

	// Optional setup:
	// email.template = '<div>{{peter}}, {{peter}} pumpkin eater, Had a wife but couldn't keep her; <a href="{{more}}">more</a></div>'
	// email.templateData = {name:'Peter', more: 'https://en.wikipedia.org/wiki/Peter_Peter_Pumpkin_Eater'}
	// email.templateType = 'handlebars'

	email.send(params, function(err, data) {
		if (err)
			console.log(err, err.stack); // error
		else
			console.log(data); // success
	}

## Tests

Make a copy of the `test/conf.sample.coffee` and update if necessary.

	cp test/conf.sample.coffee test/conf.coffee // update conf.coffee
	mocha test/email.coffee
