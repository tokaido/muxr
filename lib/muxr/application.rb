module Muxr
  class Application
    def self.new(directory, options = {})
      return super if self != Application

      directory = File.expand_path(directory)

      if File.exist?(File.join(directory, "Procfile"))
        ProcfileApp.new(directory, options)
      end
    end

    def initialize(directory, options)
      @directory = directory
      @options = options
    end

    def spawn
      spawn_monitor execute_command
    end

    def restart
      monitor execute_command
    end

    def kill
      @killed = true
    end

    def port
      @options[:port]
    end

    def host
      @options[:host]
    end

  private
    def execute_command
      Dir.chdir(@directory) do
        Bundler.with_clean_env do
          Process.spawn({ "PORT" => port.to_s }, command)
        end
      end
    end

    def spawn_monitor(pid)
      Thread.new { monitor(pid) }
    end

    def monitor(pid)
      status = loop do
        break if @killed
        _, status = Process.wait2(pid, Process::WNOHANG)
        break status if status

        sleep 1
      end

      restart if status
    end

    def command
      raise NotImplemented
    end
  end

  class ProcfileApp < Application
    def initialize(directory, options)
      super

      @procfile = File.read(File.join(@directory, "Procfile"))
    end

  private
    def command
      @command ||= begin
        if web = @procfile.match(/^web:\s*(.*)$/)
          web[1]
        end
      end
    end
  end
end
