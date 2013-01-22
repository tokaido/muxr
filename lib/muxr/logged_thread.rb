require "logger"

module Muxr
  class LoggedThread
    COLORS = {
      "DEBUG"   => "",   # normal
      "ERROR"   => "31", # red
      "WARN"    => "33", # yellow
      "INFO"    => "37", # grey
      "FATAL"   => "31", # red
      "UNKNOWN" => "34", # blue
    }

    def self.new(logger=default_logger)
      Thread.new do
        begin
          yield
        rescue Exception => e
          logger.error "#{e.class}: #{e.message}"

          e.backtrace.each do |line|
            logger.error line
          end
          raise
        end
      end
    end

    def self.default_logger
      logger = Logger.new(STDOUT)
      logger.formatter = proc do |severity, _, _, message|
        color = COLORS[severity]

        if STDOUT.tty?
          "\e[#{color}m#{message}\e[0m\n"
        else
          "#{message}\n"
        end
      end
      logger
    end
  end
end
