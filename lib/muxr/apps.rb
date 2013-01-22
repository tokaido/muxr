module Muxr
  class Apps
    def initialize
      @apps = []

      @started = false
      @stopped = false

      @mutex = Mutex.new
    end

    def [](host)
      if app = @apps.find { |a| a.host == host }
        app.port
      end
    end

    def start
      @mutex.synchronize do
        @apps.each(&:spawn)
        @started = true
      end
    end

    def stop
      @mutex.synchronize do
        @stopped = true
        @apps.each(&:kill)
      end
    end

    def add(app, responder=nil)
      @mutex.synchronize do
        return :stopped if @stopped

        return :unavailable_port unless port_available?(app.port)
        return :dup_host unless host_available?(app.host)
        return :dup_dir unless directory_available?(app.directory)

        app.spawn if @started

        report_booted(app, responder) if responder

        @apps.push(app)

        return :added
      end
    end

    def remove(app)
      @mutex.synchronize do
        return :stopped if @stopped
        app.kill if @started

        @apps.delete(app)
      end
    end

  private
    def directory_available?(directory)
      !@apps.find { |a| a.directory == directory }
    end

    def host_available?(host)
      !self[host]
    end

    def port_available?(port)
      Timeout.timeout(1) do
        check_port(port)
      end
    rescue Timeout::Error
    end

    def check_port(port)
      s = TCPServer.new("0.0.0.0", port)
      s.close
      true
    rescue Errno::ECONNREFUSED, Errno::EADDRINUSE
    end

    def report_booted(app, responder)
      LoggedThread.new do
        begin
          s = TCPSocket.new("0.0.0.0", app.port)
          s.close
          responder.app_booted(app)
        rescue Errno::ECONNREFUSED
          sleep 1
          retry
        end
      end
    end
  end
end
