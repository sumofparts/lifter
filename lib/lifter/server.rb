require 'eventmachine'

module Lifter
  class Server
    attr_reader :config, :file_manager

    def initialize(&config)
      @config = Config.new(&config)
      @file_manager = FileManager.new(@config)
    end

    def start
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
