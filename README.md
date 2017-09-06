# AWS Simple Email Service (SES) Template Mailer

Send HTML or plain text templates through Amazon Web Services Simple Email Service (SES) using Handlebars, Pug, EJS or Underscore. This is essentially a wrapper for [ses.sendEmail](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SES.html#sendEmail-property).

## Install

	npm install --save ses-template-mailer

## Usage

	Email = require('ses-template-mailer')
	email = new Email(recipient, credentials);
	email.send(function(error, result){});

## Options

| Name				| Type					| Description
| --------------	|-----------------------|------
| `options`			| Object or [Object]		| Options are the same as [AWS SES sendMail](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SES.html#sendEmail-property) with the following additions. You may also pass an array of multiple email options. Multiple emails will be sent at 90 emails per second. 
| `options.Message.TemplateData` | Object	| The data to parse the template with. This can also be set with `email.templateData` before calling send.
| `options.Message.TemplateType` | String	| The template engine to use. Must be one of the following: "handlebars", "pug", "ejs", "underscore". Handlebars is the default. This can also be set with `email.templateType` before calling send.
| `options.Message.Body.Html`	 | String	| The text email template. Should either be an html template string or a valid url eg: `https://mybucket.s3.amazonaws.com/template.handlebars`. Using an extension name like "handlebars", "pug", "ejs" or "underscore" will overwrite `TemplateType`.
| `options.Message.Body.Text`	 | String	| The text email template. Should either be a text template string or a valid url eg: `https://mybucket.s3.amazonaws.com/template.handlebars`. Using an extension name like "handlebars", "pug", "ejs" or "underscore" will overwrite `TemplateType`. If `Message.Body.Text` is `null` then a plain text email will be generated from the HTML. *Note: Since Pug cannot parse plain text emails text is automatically parsed from html, be sure and nullify text property (`Message.Body.Text=null`) if you're using Pug.*
| `credentials`		| Object				| Config options are the the same as [AWS Config](http://docs.aws.amazon.com/AWSJavaScriptSDK/guide/node-configuring.html). If you've already set up your conf globally you can leave this `null`


## Properties

### `templates` (String)

The text email template. Should either be an html template string or a valid url eg: `https://mybucket.s3.amazonaws.com/template.handlebars`. Using an extension name like "handlebars", "pug", "ejs" or "underscore" will overwrite `TemplateType`.

### `templateData` (Object)

The data to parse the template with. Refer to your desired templating engine for more details.

### `templateType` (String)

The template engine to use. Must be one of the following: "handlebars", "pug", "ejs", "underscore". Handlebars is the default.

### `rateLimit` (Number=90)

If sending multiple emails with with `send` delivery will be throttled ensure your don't go over your rate limit. Default: 90.

### send (Function)

Dispatch emails

#### Parameters

| Name											| Type					| Description
| --------------								|-----------------------|------
| `callback`									| Function <optional>	| A callback function. If no callback is given events are emitted.
| `callback.errors`								| [Error]				| A collection of errors or `null` if there were no errors
| `callback.results`							| [Object]				| The result of each send
| `callback.results.MessageId`					| String				| The message id retuned from SES
| `callback.results.ResponseMetadata`			| Object				| The response meta data retuned from SES
| `callback.results.ResponseMetadata.RequestId`	| String				| The request id retuned from SES

## Events

### `COMPLETE_EVENT`

Event triggered when all emails have been processed and sent.

#### Parameters

| Name									| Type					| Description
| --------------						|-----------------------|------
| `errors`								| [Error]				| A collection of errors or `null` if there were no errors
| `results`								| [Object]				| The result of each send
| `results.MessageId`					| String				| The message id retuned from SES
| `results.ResponseMetadata`			| Object				| The response meta data retuned from SES
| `results.ResponseMetadata.RequestId`	| String				| The request id retuned from SES

### `SEND_EVENT`

Event trigged each time an email is sent.

| Name									| Type					| Description
| --------------						|-----------------------|------
| `result`								| Object				| The result of each send
| `result.MessageId`					| String				| The message id retuned from SES
| `result.ResponseMetadata`				| Object				| The response meta data retuned from SES
| `result.ResponseMetadata.RequestId`	| String				| The request id retuned from SES

### `ERROR_EVENT`

Event trigger when an email failed to send.

| Name									| Type					| Description
| --------------						|-----------------------|------
| `error`								| Error				| The send error



## Examples:

### Sending One Email (with callbacks)

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
			region: 'us-west-2'
		}

	);

	// Optional setup:
	// email.template = '<div>{{peter}}, {{peter}} pumpkin eater, Had a wife but couldn't keep her; <a href="{{more}}">more</a></div>'
	// email.templateData = {name:'Peter', more: 'https://en.wikipedia.org/wiki/Peter_Peter_Pumpkin_Eater'}
	// email.templateType = 'handlebars'

	email.send(function(err, data) {
		if (err)
			console.log(err, err.stack); // error
		else
			console.log(data); // success
	}

### Sending Multiple Emails (with events)

	Email = require('../lib/email')
	email = new Email([recipient1, recipient2, recipient3,]);
	email.rateLimit = 200
	email.on(Email.COMPLETE_EVENT, function(errors, results, data){
		console.log(results.length+" of "+data.length+" emails have been sent.")
	});
	email.on(Email.SEND_EVENT, function(result){
		console.log('email sent')
	});
	email.on(Email.ERROR_EVENT, function(error){
		console.log(error.stack)
	});
	email.send()



## Tests

Make a copy of the `test/conf.sample.coffee` and update if necessary.

	cp test/conf.sample.coffee test/conf.coffee // update conf.coffee
	mocha test/email.coffee
