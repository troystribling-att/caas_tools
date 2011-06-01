require 'rubygems'
require 'pony' 

def send_email(to,subject, msg, config)
  Pony.mail(:to => to, :subject => subject, :body => msg, 
            :via => :smtp, :via_options => {:address => config[:smtp_server], 
                                            :port => config[:port], 
                                            :enable_starttls_auto => true, 
                                            :user_name => config[:user_name], 
                                            :password => config[:password], 
                                            :authentication => :plain, 
                                            :domain => "HELO"})
end