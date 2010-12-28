#!/usr/bin/env ruby
require 'rubygems'
require 'net/https'
require 'uri'
require 'json'

# Set the desired parameters on the command line 
CUSTOMER_NAME = ENV['DYNECT_CUST']
USER_NAME = ENV['DYNECT_USER']
PASSWORD = ENV['DYNECT_PASS']
ZONE = ENV['DYNECT_ZONE']
FQDN = ENV['DYNECT_FQDN']
IPADDR = ENV['EC2_PUBLIC_IPV4']

# Set up our HTTP object with the required host and path
url = URI.parse('https://api2.dynect.net/REST/Session/')
headers = { "Content-Type" => 'application/json' }
http = Net::HTTP.new(url.host, url.port)
http.set_debug_output $stderr
http.use_ssl = true

# Login and get an authentication token that will be used for all subsequent requests.
session_data = { :customer_name => CUSTOMER_NAME, :user_name => USER_NAME, :password => PASSWORD }

resp, data = http.post(url.path, session_data.to_json, headers)
result = JSON.parse(data)

auth_token = ''
if result['status'] == 'success'    
	auth_token = result['data']['token']
else
	puts "Command Failed:\n"
	# the messages returned from a failed command are a list
	result['msgs'][0].each{|key, value| print key, " : ", value, "\n"}
end

# New headers to use from here on with the auth-token set
headers = { "Content-Type" => 'application/json', 'Auth-Token' => auth_token }

# Get all the A records
url = URI.parse("https://api2.dynect.net/REST/ARecord/#{ZONE}/#{FQDN}/") 
resp, data = http.get(url.path, headers)

# Get the records in an array
records = JSON.parse(data) 

# Initialize the id
record_uri = "" 

# Loop through the records and fill in the id when/if it is found
records['data'].each do |record|
	url = URI.parse("https://api2.dynect.net" + record ) 
	resp, data = http.get(url.path, headers)	
	record_data = JSON.parse(data)
	if record_data['data']['rdata']['address'] == IPADDR
		record_uri = record 
		break
	end
end

# If the record was found... delete it!
if record_uri != ""

	# Remove the A record
	url = URI.parse("https://api2.dynect.net" + record_uri) 
	resp, data = http.delete(url.path, headers)
	print 'Delete ARecord Response: ', data, '\n'; 

	# Publish the changes
	url = URI.parse("https://api2.dynect.net/REST/Zone/#{ZONE}/") 
	publish_data = { "publish" => "true" }
	resp, data = http.put(url.path, publish_data.to_json, headers)
	print 'PUT Zone Response: ', data, '\n'; 
end

# Logout
url = URI.parse('https://api2.dynect.net/REST/Session/')
resp, data = http.delete(url.path, headers)
print 'DELETE Session Response: ', data, '\n'; 