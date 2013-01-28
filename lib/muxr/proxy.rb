require "socket"

module Muxr
  class Proxy
    def initialize(apps, port)
      @server = TCPServer.new("127.0.0.1", port)
      puts "Started Proxy at #{port}"
      @apps = apps
      @started = false
    end

    def start
      @started = true

      LoggedThread.new { accept }
    end

    def stop
      @started = false
    end

  private

    def accept
      while @started
        accept_request do |proxy_socket|
          LoggedThread.new do
            host, parsed_lines = find_host(proxy_socket)

            if host && port = @apps[host]
              connect_proxy(proxy_socket, port, parsed_lines)
            end
          end
        end
      end

      @server.close
    end

    def accept_request
      proxy_socket = @server.accept
      yield proxy_socket
    end

    def find_host(proxy_socket)
      # TODO: Timeout
      # TODO: Overflow

      parsed_lines = []

      Timeout.timeout(5) do
        host = loop do
          IO.select([proxy_socket])

          line = proxy_socket.readline
          parsed_lines << line

          proxy_socket.close and break if line.empty?

          if host = line[/^Host:\s*(.*?)(:\d+)?\r?$/, 1]
            break host
          else
            # TODO: Handle error gracefully
          end
        end

        return [ host, parsed_lines ]
      end
    rescue Timeout::Error
    rescue EOFError
    end

    def connect_proxy(proxy_socket, port, parsed_lines)
      connect_to_app(port) do |app_socket|
        parsed_lines.each { |line| app_socket.puts line }
        app_socket.flush

        begin_proxy(proxy_socket, app_socket)
      end
    ensure
      proxy_socket.close
    end

    def connect_to_app(port)
      app_socket = TCPSocket.new("127.0.0.1", port)
      yield app_socket
    rescue Errno::ECONNREFUSED
      sleep 1
      retry
    ensure
      app_socket.close if app_socket
    end

    def begin_proxy(proxy_socket, app_socket)
      loop do
        ready_sockets, _, _ = IO.select([proxy_socket, app_socket])

        begin
          ready_sockets.each do |socket|
            data = socket.readpartial(4096)

            other = socket == proxy_socket ? app_socket : proxy_socket

            other.write data
            other.flush
          end
        rescue EOFError, Errno::ECONNRESET, Errno::EPIPE => e
          break
        end
      end
    end
  end
end
