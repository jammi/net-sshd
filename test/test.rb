
require 'lib/net/sshd'

host = '127.0.0.1'
port = 10022
puts "Starting listener on #{host}:#{port}"
stdout = $stdout
stderr = $stderr
Thread.new do
  Thread.abort_on_exception = true
  Thread.pass
  Net::SSHD.start( host, port )
end

ssh_cmd = "ssh #{host} -p #{port} test"
puts "Starting client connection using #{ssh_cmd}"
puts `#{ssh_cmd}`

puts "Starting client connection with Net::SSH.."
Net::SSH.start( host, 'user', :port => port ) do |ssh|
  puts ssh.exec!("test").inspect
end
