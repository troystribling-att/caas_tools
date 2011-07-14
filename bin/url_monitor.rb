#-------------------------------------------------------------------------------------------------
this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_dir)
require 'yaml'
require 'rest_client'

#-------------------------------------------------------------------------------------------------
URLS = File.open(ARGV.first){|yf| YAML::load(yf)}

#-------------------------------------------------------------------------------------------------
START_TIME = Time.now.to_i
TIME_DELTA = 10

#-------------------------------------------------------------------------------------------------
puts "URL, Time (epoch), Latency (ms), Status"

#-------------------------------------------------------------------------------------------------
def write_data(url, time, latency, status)
  puts "#{url}, #{time}, #{latency}, #{status}"
end

#-------------------------------------------------------------------------------------------------
while true
  URLS.each do |url|
    status = 200
    begin_test = Time.now
    begin
      res = RestClient.get url
    rescue RestClient::RequestFailed, RestClient::ResourceNotFound, RestClient::Unauthorized,  RestClient::NotModified => err 
      status = err.http_code
    rescue
      status = -1
    end
    write_data(url, begin_test.to_i, (1000*(Time.now.to_f - begin_test.to_f)).to_i, status)
  end    
  sleep(TIME_DELTA)
end
