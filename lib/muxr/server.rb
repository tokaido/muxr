module Muxr
  class Server
    def initialize(apps, options = {})
      @apps = apps
      @options = options
      @proxy = nil
    end

    def boot
      @apps.start
      register_traps

      @proxy = Proxy.new(@apps, port)
      @proxy.start
      sleep
    end

    def kill
      @apps.stop
      @proxy.stop

      Process.waitall
    end

  private
    def port
      @options[:port]
    end

    def register_traps
      trap(:INT) do
        puts " Exiting"
        exit
      end

      at_exit do
        kill
      end
    end
  end
end
