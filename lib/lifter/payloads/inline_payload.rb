module Lifter
  module Payloads
    class InlinePayload
      def initialize(connection, file_manager)
        @connection = connection
        @file_manager = file_manager
      end
    end
  end
end
