require "pty"

unless defined?(Bundler.with_clean_env)
  module Bundler
    def self.with_clean_env(*)
      yield
    end
  end
end

module Muxr
  module Helpers
    def self.options
      { rails: 
          { host: '-b', additions: []},
        rackup:
          { host: '-o', additions: []},
        unicorn:
          { host: '-o', additions: []},
        thin:
          { host: '-a', additions: [:start]}
      }
    end

    def self.is_rails_server? command
      !!(command =~ /rails/)
    end
  end

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

    attr_reader :directory, :failed

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
      return if @failed

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
      exitstatus = loop do
        _, status = Process.wait2(pid)
        break status.exitstatus
      end

      if exitstatus && exitstatus > 0
        @failed = true
        @options[:delegate].failed(self) if @options[:delegate]
      else
        restart unless @killed
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
      @command ||= relax_command
    end

    def relax_command 
      relaxed_command = ""

      if web_entry = @procfile.match(/^web:\s*(.*)$/) 
        cmd_pieces = web_entry[1].split(" ") << " "
        possible_server = cmd_pieces[cmd_pieces.index("exec") + 1].to_sym

        if Helpers.is_rails_server?(web_entry[1])
          relaxed_command = web_entry[1].sub('server', 'server puma')
          relaxed_command << " #{Helpers.options[:rails][:host]} "
        else
          relaxed_command = web_entry[1]

          begin
            with_flag = Helpers.options.fetch(possible_server) { Hash[:host, "-o"] }[:host]
            relaxed_command << " " << with_flag << " "
          rescue
            relaxed_command << " " << Helpers.options[:rackup][:host] << " "
          end
        end

        relaxed_command << "127.0.0.1"
      end

      relaxed_command << " -p $PORT"
      relaxed_command << " #{Helpers.options.fetch(possible_server){Hash[:additions, []]}[:additions].join(' ')}"
      relaxed_command
    end
  end

  class RackApp < Application
    def command
      "bundle exec rackup #{Helpers.options[:rackup][:host]} 127.0.0.1 --server puma -p $PORT"
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
