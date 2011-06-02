#!/usr/bin/env ruby

# Copyright 2010 Juha-Jarmo Heinonen <o@sorsacode.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the ‘Software’), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'rubygems'
require 'randgen'
require 'net/ssh'
require 'eventmachine'
require 'hexy'

module Net
  module SSHD
    RAND_GEN = RandGen.new( 4096 )
    PROTO_VERSION = "SSH-2.0-Ruby/Net::SSHD_#{Net::SSH::Version::CURRENT} #{RUBY_PLATFORM}"
    class Listener < EM::Connection
      def hexy( str )
        puts Hexy.new(str).to_s
      end
      def if_is_ssh
        if @buffer.start_with?('SSH-2.0-')
          @is_ssh = true
          @buffer.slice!(0..7)
          puts "is ssh"
          if_is_client_version
        elsif @buffer.bytesize > 8
          @is_ssh = false
          puts "not ssh, closing conn"
          bye
        end
      end
      def if_is_client_version
        if @buffer.include?("\r\n")
          nl_offset = @buffer.index("\r\n")+1
          @client_name = @buffer.slice!(0..nl_offset).strip
          puts "client_name: #{@client_name.inspect}"
          if_is_header
        end
      end
      def if_is_header
        return unless @buffer.bytesize > 5
        @packet_length = @buffer.slice!(0..4).unpack('N').first
        @padding_length = @buffer.slice!(0..1).unpack('C').first
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
        puts "payload:"
        hexy @payload
        ssh_msg_kexinit = @payload.slice!(0..1)
        cookie = @payload.slice!(0..16)
        puts "cookie:"
        hexy cookie
        # puts "random padding: #{random_padding.inspect}"
        # puts "random padding2: #{random_padding2.inspect}"
        # m = @payload.slice!(0..1).unpack('C').first
        # mac = @payload.slice!(0..m)
        # puts "m: #{m}, mac: #{mac.inspect}"
        # puts "buffer end: #{@buffer.inspect}"
      end
      def process_packets
        @buffer += @packets.shift unless @packets.empty?
        # puts "buffer: #{@buffer.inspect}"
        if not @is_ssh
          if_is_ssh
        elsif not @client_name
          if_is_client_version
        elsif not @received_header
          if_is_header
        end
      end
      def timeout_initial
        EM::add_timer( 1 ) do
          @close_conn = ( not @received_header )
        end
      end
      def setup_vars
        @is_ssh = false
        @client_name = false
        @received_header = false
        @close_conn = false
        @packets = []
        @buffer = ''
      end
      def send_version
        send_data( "#{PROTO_VERSION}\r\n" )
      end
      def post_init
        setup_vars
        send_version
        timeout_initial
        EM::add_periodic_timer( 0.2 ) do
          print "."
          process_packets
          if @close_conn
            bye
          end
        end
      end
      def bye( delay_ms=0 )
        @close_conn = true
        sleep delay_ms/1000.0
        close_connection_after_writing
      end
      def receive_data( data )
        @packets.push( data )
        # puts "data: #{data.inspect}"
      end
    end
    def self.start( host, port, listener=Listener )
      EM::run do
        EM::start_server( host, port, listener )
      end
    end
  end
end
