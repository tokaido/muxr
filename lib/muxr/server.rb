module Muxr
  class Server
    def initialize(apps, options = {})
      @apps = apps
      @options = options
      @proxy = nil
    end

    def boot
      puts "Booting Muxr Server"
      @apps.start

      @proxy = Proxy.new(@apps, port)
      @proxy.start
    end

    def stop
      puts "Stopping Muxr Server"
      @apps.stop
      @proxy.stop

      Process.waitall
    end

  private
    def port
      @options[:port]
    end
  end
end
