module Lifter
  module Payloads
    class MultipartPayload
      CurrentPart = Struct.new(:id, :type, :name)

      def initialize(connection, file_manager, multipart_boundary)
        @connection = connection
        @file_manager = file_manager
        @reader = MultipartParser::Reader.new(multipart_boundary)

        @current_part = nil

        @params = {}

        setup_callbacks
      end

      def <<(data)
        @reader.write(data)
      end

      def cancel
        return if !current_part?

        if current_part.type == :file
          @file_manager.cancel_file(@current_part.id)
        end

        @current_part = nil
      end

      def current_part?
        !@current_part.nil?
      end

      private def setup_callbacks
        @reader.on_part do |part|
          @current_part = CurrentPart.new

          @current_part.id = SecureRandom.hex(10)
          @current_part.name = part.name

          if part.filename.nil?
            @current_part.type = :param
            @params[@current_part.name] = ''
          else
            @current_part.type = :file
            @file_manager.open_file(@connection, @current_part.id, @current_part.name, part.filename)
          end

          part.on_data do |data|
            if @current_part.type == :param
              @params[@current_part.name] << data
            else
              @file_manager.write_file_data(@connection, @current_part.id, data)
            end
          end

          part.on_end do
            @connection.request.params = @params

            if @current_part.type == :file
              @file_manager.close_file(@connection, @current_part.id)
            end

            @current_part = nil
          end
        end

        @reader.on_end do
          @connection.respond(200, 'OK')
          @connection.close
        end

        @reader.on_error do |message|
          if !@current_part.nil? && @current_part.type == :file
            @file_manager.cancel_file(@connection, @current_part.id)
          end

          @current_part = nil
        end
      end
    end
  end
end
