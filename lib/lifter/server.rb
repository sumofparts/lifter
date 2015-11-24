require 'eventmachine'

module Lifter
  class Server
    attr_reader :config, :file_manager

    def initialize(&config)
      @config = Config.new(&config)
      @file_manager = FileManager.new(@config)
    end

    def start
      # Ensure progress and completed work directories are established.
      progress_dir = "#{@config.get(:working_dir)}/progress"
      completed_dir = "#{@config.get(:working_dir)}/completed"
      FileUtils.mkdir(progress_dir) if !File.directory?(progress_dir)
      FileUtils.mkdir(completed_dir) if !File.directory?(completed_dir)

      EventMachine.epoll if EventMachine.epoll?
      EventMachine.kqueue if EventMachine.kqueue?

      EventMachine.run do
        host = @config.get(:host)
        port = @config.get(:port)

        EventMachine.start_server(host, port, Connection) do |connection|
          connection.server = self
        end
      end
    end
  end
end
