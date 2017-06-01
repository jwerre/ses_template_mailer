
module.exports =

	# See aws credentials. http://docs.aws.amazon.com/AWSJavaScriptSDK/guide/node-configuring.html
	credentials:
		accessKeyId: 'my_aws_access_key'
		secretAccessKey: 'my_aws_secret_key'
		region: 'us-west-2'

	from: 'success@simulator.amazonses.com'

	to: [
		'AWS Simulator <success@simulator.amazonses.com>'
	]

	templateData:
		email: "tester@email.com"
		amazing: true

	templateUris:
		handlbars:
			text: 'https://gist.githubusercontent.com/jwerre/00b42eb76a7aee6c6ddf/raw/dbfe65c1c399323544689c85bf65128d4440cb2b/text_email_template.handlebars'
			html: 'https://gist.githubusercontent.com/jwerre/24e327073cc2eed8aaaf/raw/b410e66cf52fc1b96f1d1fe9daa92f27c48dcd53/html_email_template.handlbars'
		pug:
			text: 'Can not send plain text emails with Pug. Text email will be parsed from HTML.'
			html: 'https://gist.githubusercontent.com/jwerre/d3362650657cde6e19a8/raw/36ce36377898624591aecd32f3582d0cec511098/test_email_template.pug'
		ejs:
			text: 'https://gist.githubusercontent.com/jwerre/9bf4a6f8b17183e0f5cf/raw/47087c3125a78acff72b2c195ed15096866dabd9/text_email_template.ejs'
			html: 'https://gist.githubusercontent.com/jwerre/c28ab484c4c58e0feb6b/raw/66df854a462afb81e00e8e47d464356bd00fbf74/html_email_template.ejs'
		underscore:
			text: 'https://gist.githubusercontent.com/jwerre/f3b3032f77933e23f69c/raw/50fe9766774c3d4dc6007856c9e39840c1709516/text_email_template.underscore'
			html: 'https://gist.githubusercontent.com/jwerre/50f03478a66c1199559f/raw/018ee8a6c9fec9f733946db8ba0a715a59135a1b/html_email_template.underscore'

	templates:
		handlbars:
			text: 	"""
				You've just sent a plain text email with Handlebars
				this email was sent to {{email}}
				{{#if amazing}}
					You are amazing!
				{{else}}
					You did it!
				{{/if}}
			"""
			html: """
				<h1> You've just sent an HTML template with Handlebars</h1>
				<p> This email was sent to <a href="mailto:{{email}}">{{email}}</a> </p>
				{{#if amazing}}
					<p>You are amazing!</p>
				{{else}}
					<p>You did it!</p>
				{{/if}}
			"""
		pug:
			text: "Can not send plain text emails with Pug—text email will be parsed from HTML."
			html: """
				h1 You've just sent a Pug email template
				p this email was sent to
					a(href="mailto:"+email)= email
				if amazing
					p You are amazing!
				else
					p You did it!
			"""
		ejs:
			text: 	"""
				You've just sent a plain text email with EJS
				this email was sent to <%= email %>
				<%= if (amazing) { %>
					You are amazing!
				<%= } else { %>
					You did it!
				<%= } %>
			"""
			html: """
				<h1> You've just sent an HTML template with EJS</h1>
				<p> This email was sent to <a href="mailto:<%= email %>">email</a> </p>
				<% if (amazing) { %>
					<p>You are amazing!</p>
				<% } else { %>
					<p>You did it!</p>
				<% } %>
			"""
		underscore:
			text: 	"""
				You've just sent a plain text email with Underscore
				this email was sent to <%= email %>
				<% if (amazing) { %>
					You are amazing!
				<% } else { %>
					You did it!
				<% } %>
			"""
			html: """
				<h1> You've just sent an HTML template with Underscore</h1>
				<p> This email was sent to <a href="mailto:<%= email %>">email</a> </p>
				<% if (amazing) { %>
					<p>You are amazing!</p>
				<% } else { %>
					<p>You did it!</p>
				<% } %>
			"""
