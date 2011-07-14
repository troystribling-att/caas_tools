#-------------------------------------------------------------------------------------------------
this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_dir)
require 'yaml'
require 'rest_client'

#-------------------------------------------------------------------------------------------------
URLS = File.open(ARGV.first){|yf| YAML::load(yf)}
FILE = File.open(ARGV.last, 'w')

#-------------------------------------------------------------------------------------------------
START_TIME = Time.now.to_i
TIME_DELTA = 60

#-------------------------------------------------------------------------------------------------
FILE.write("URL, Timestamp, Time (epoch), Latency (ms), Status\n")

#-------------------------------------------------------------------------------------------------
def write_data(url, time, latency, status)
  FILE.write("#{url}, #{time}, #{time.to_i}, #{latency}, #{status}\n")
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
    write_data(url, begin_test, (1000*(Time.now.to_f - begin_test.to_f)).to_i, status)
  end    
  sleep(TIME_DELTA)
end
