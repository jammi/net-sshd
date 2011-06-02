require 'net/ssh'
require 'eventmachine'

module Net
  module SSHD

    #RAND_GEN = File.open('/dev/urandom','rb'){|f| f.read(4096) }
    PROTO_VERSION = "SSH-2.0-Ruby/Net::SSHD_%s %s" % [Net::SSH::Version::CURRENT, RUBY_PLATFORM]

    class Listen < EM::Connection

      def handshake_version
        if @buffer[0...8] == 'SSH-2.0-'
          @buffer.slice!(0...8)
          handshake_clientname
        else
          puts "not ssh, closing conn"
          bye
        end
      end

      def handshake_clientname
        @state = :handshake_clientname
        if (offset = @buffer.index("\r\n"))
          @client_name = @buffer.slice!(0...offset).strip
          puts "client_name: %s" % [@client_name]
          handshake_header
        end
      end

      def handshake_header
        @state = :handshake_header
        return unless @buffer.bytesize > 5
        @packet_length, @padding_length = @buffer.slice!(0...5).unpack('NC')

        puts "packet length: #{@packet_length}"
        puts "padding length: #{@padding_length}"
        puts "buffer length: #{@buffer.bytesize}"

        n1 = @packet_length - @padding_length - 5
        @payload = @buffer.slice!(0..n1)

        n2 = @padding_length
        random_padding = @buffer.slice!(0..n2)
        # random_padding2 = @payload.slice!(0..(n2-3))

        puts "-"*80
        puts "packet length: #{@payload.bytesize} vs #{n1}"
        puts "padding length: #{random_padding.bytesize} vs #{n2}"
        puts "payload: #{@payload.inspect}"
        ssh_msg_kexinit = @payload.slice!(0..1)
        cookie = @payload.slice!(0..16)
        puts "cookie: #{cookie.inspect}"
        # puts "random padding: #{random_padding.inspect}"
        # puts "random padding2: #{random_padding2.inspect}"
        # m = @payload.slice!(0..1).unpack('C').first
        # mac = @payload.slice!(0..m)
        # puts "m: #{m}, mac: #{mac.inspect}"
        # puts "buffer end: #{@buffer.inspect}"
      end

      def process_packets
        case @state
        when :post_init
          handshake_version
        when :handshake_clientname
          handshake_clientname
        when :handshake_header
          handshake_header
        end
      end

      def post_init
        @buffer, @state = "", :post_init
        send_data( PROTO_VERSION + "\r\n" )
        EM.add_timer(1.5){
          bye if [:post_init, :handshake_clientname].include?(@state)
        }
      end

      def bye( delay_ms=0 )
        EM.add_timer(delay_ms/1000.0){ close_connection_after_writing }
      end

      def receive_data(data)
        p ['data', data.size, data]
        @buffer += data
        process_packets
      end
    end

    def self.start(host, port, *args)
      EM.start_server(host, port, Listen, *args)
    end
  end
end


if $0 == __FILE__
  EM.run do
    Net::SSHD.start('127.0.0.1', 8022)
  end
end
