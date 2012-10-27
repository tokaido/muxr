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

    def add(app)
      @mutex.synchronize do
        return if @stopped
        app.spawn if @started

        @apps.push(app)
      end
    end

    def remove(app)
      @mutex.synchronize do
        return if @stopped
        app.kill if @started

        @apps.delete(app)
      end
    end
  end
end
