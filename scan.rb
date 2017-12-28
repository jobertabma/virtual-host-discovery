require 'net/http'
require 'openssl'

def get_option(key)
  selected = ARGV.select do |argument|
    argument.start_with?(format('--%s=', key))
  end.first

  return unless selected

  selected.split('=').last
end

def write_results(result, file_path)
  begin
    puts " Start writing final results"
    file = File.open(file_path, "ab+")
    file.write(result)
    puts " Finish writing final results"
  rescue IOError => e
    #some error occur, dir not writable etc.
    puts e;
  ensure
    file.close unless file.nil?
  end
end

ip_address = get_option('ip')
host = get_option('host')
ignore_http_codes = get_option('ignore-http-codes') || '404'
ignore_content_length = get_option('ignore-content-length') || 0
wordlist_file = get_option('wordlist') || 'wordlist'
ssl = get_option('ssl') || 'off'
port = get_option('port') || (ssl == 'on' ? 443 : 80)
output = get_option('output') || 'output.txt'

if ip_address.nil? || host.nil?
  puts 'Usage: ruby scan.rb --ip=<ip-address> --host=<host>'
  puts ''
  puts '  Arguments'
  puts '    --ip=<ip-address>'
  puts '    --host=<host>'
  puts '    --port=<port>'
  puts '    --ignore-http-codes=<comma separated list of http codes>'
  puts '    --ignore-content-length=<value>'
  puts '    --wordlist=<file location>'
  puts '    --ssl=<on|off>'
  puts '    --output=<output - default current directory, output.txt>'
  exit
end

port = port.to_i
ignore_http_codes = ignore_http_codes.split(',').map { |code| code.to_i }
ignore_content_length = ignore_content_length.to_i
result = StringIO.new
IO.read(File.expand_path(wordlist_file)).split("\n").each do |virtual_host|
  hostname = virtual_host.gsub('%s', host)

  Net::HTTP.start(ip_address, port, use_ssl: ssl == 'on', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Head.new('/')
    request['Host'] = port == 80 ? hostname : format('%s:%d', hostname, port)
    request['Accept'] = '*/*'

    response = http.request(request)

    next if ignore_http_codes.include?(response.code.to_i)
    next if ignore_content_length > 0 && ignore_content_length == response['content-length'].to_i

    result << "Found: #{hostname} (#{response.code})\n"
    response.to_hash.each do |header, values|
      result << " #{header}:\n"
      values.each do |value|
        result << " #{value}\n"
      end
    end
  end
end

puts result.string
write_results(result.string, output)
