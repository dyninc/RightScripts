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
REGION = ENV['DYNECT_REGION']
IPADDR = ENV['EC2_PUBLIC_IPV4']

# replace any spaces in the region with the request string replacement %20
REGION.gsub!(" ", "%20")

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

# Remove the IP from the GSLB region's pool
url = URI.parse("https://api2.dynect.net/REST/GSLBRegionPoolEntry/#{ZONE}/#{FQDN}/#{REGION}/#{IPADDR}") 
resp, data = http.delete(url.path, headers)

print 'Delete GSLBRegionPoolEntry Response: ', data, '\n'; 

# Logout
url = URI.parse('https://api2.dynect.net/REST/Session/')
resp, data = http.delete(url.path, headers)
print 'DELETE Session Response: ', data, '\n'; 
