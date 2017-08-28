require 'net/http'

def get_option(key)
  selected = ARGV.select do |argument|
    argument.start_with?(format('--%s=', key))
  end.first

  return unless selected

  selected.split('=').last
end

ip_address = get_option('ip')
host = get_option('host')
port = get_option('port') || 80
ignore_http_codes = get_option('ignore-http-code') || '404'
ignore_content_length = get_option('ignore-content-length') || 0

if ip_address.nil? || host.nil?
  puts 'Usage: ruby scan.rb --ip=<ip-address> --host=<host>'
  puts ''
  puts '  Arguments'
  puts '    --ip=<ip-address>'
  puts '    --host=<host>'
  puts '    --port=<port>'
  puts '    --ignore-http-codes=<comma separated list of http codes>'
  puts '    --ignore-content-length=<value>'
  exit
end

port = port.to_i
ignore_http_codes = ignore_http_codes.split(',').map { |code| code.to_i }
ignore_content_length = ignore_content_length.to_i

IO.read('wordlist').split("\n").each do |virtual_host|
  hostname = virtual_host.gsub('%s', host)
  
  http = Net::HTTP.new(ip_address, port)
  request = Net::HTTP::Head.new('/')
  request['Host'] = port == 80 ? hostname : format('%s:%d', hostname, port)
  request['Accept'] = '*/*'
  
  response = http.request(request)

  next if ignore_http_codes.include?(response.code.to_i)
  next if ignore_content_length > 0 && ignore_content_length == response['content-length'].to_i

  puts "Found: #{hostname} (#{response.code})"
  response.to_hash.each do |header, values|
    puts "  #{header}:"
    values.each do |value|
      puts "    #{value}"
    end
  end
end
