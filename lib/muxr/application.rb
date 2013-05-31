require "pty"

unless defined?(Bundler.with_clean_env)
  module Bundler
    def self.with_clean_env(*)
      yield
    end
  end
end

module Muxr
  class Application
    def self.new(directory, options = {})
      return super if self != Application

      if directory.nil?
        ManagedApp.new(directory, options)
      else
        directory = File.expand_path(directory)

        if File.exist?(File.join(directory, "Procfile"))
          ProcfileApp.new(directory, options)
        else
          RackApp.new(directory, options)
        end
      end
    end

    attr_reader :directory

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
      Process.kill(:INT, @pid)
    end

    def port
      @options[:port]
    end

    def host
      @options[:host]
    end

    def out
      @options[:out]
    end

    def err
      @options[:err]
    end

  private
    def execute_command
      Dir.chdir(@directory) do
        Bundler.with_clean_env do
          ENV["PORT"] = port.to_s

          log = File.open(out, 'a')
          stdin, _, @pid = PTY.spawn(command)

          LoggedThread.new do
            stdin.each do |line|
              log.puts line; log.flush
            end
          end
        end
      end

      @pid
    end

    def spawn_monitor(pid)
      LoggedThread.new { monitor(pid) }
    end

    def monitor(pid)
      status = loop do
        _, status = Process.wait2(pid)
        break status
      end

      restart unless @killed
    rescue Errno::ECHILD
      restart unless @killed
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

  class RackApp < Application
    def command
      "bundle exec rackup -p $PORT"
    end
  end

  class ManagedApp < Application
    def execute_command(*)
    end

    def monitor(*)
    end

    def spawn_monitor(*)
    end
  end
end
