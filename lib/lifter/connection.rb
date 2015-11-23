require 'eventmachine'
require 'http/parser'

module Lifter
  class Connection < EventMachine::Connection
    Request = Struct.new(:headers, :params, :remote_ip, :origin)

    PAYLOAD_METHODS = ['put', 'post'].freeze
    OPTIONS_METHOD = 'options'.freeze
    CONTENT_TYPE_KEY = 'content-type'.freeze
    MULTIPART_CONTENT_TYPE = 'multipart/form-data'.freeze

    attr_reader :request

    def initialize
      super

      @is_multipart = nil
      @has_payload = nil
      @options_request = nil

      @multipart_reader = nil
      @inline_reader = nil

      @server = nil
      @request = Request.new

      @gracefully_close = false

      @parser = HTTP::Parser.new

      @parser.on_message_begin = proc do
        start_request
      end

      @parser.on_headers_complete = proc do
        process_headers

        if payload?
          start_payload
        else
          if request_method?(:options)
            handle_options_request
          else
            close(gracefully: true)
          end
        end
      end

      @parser.on_body = proc do |data|
        receive_payload_data(data) if payload?
      end

      @parser.on_message_complete = proc do
        finish_request
      end
    end

    def server=(server)
      raise ArgumentError.new('incorrect type') if !server.is_a?(Server)

      @server = server
    end

    def file_manager
      raise StandardError.new('server not defined') if @server.nil?

      @server.file_manager
    end

    def receive_data(data)
      @parser << data
    end

    def unbind
      @payload.cancel if !gracefully_close? && !@payload.nil?
    end

    def close(opts = {})
      @gracefully_close = opts[:gracefully] == true

      EventMachine.next_tick do
        close_connection(true)
      end
    end

    def cancel
      @payload.cancel if !@payload.nil?
      close(gracefully: true)
    end

    def gracefully_close?
      @gracefully_close == true
    end

    def http_version
      @parser.http_version || [1, 0]
    end

    def remote_ip
      '127.0.0.1'
    end

    def respond(code, status, headers = {}, body = '')
      return if gracefully_close?

      EventMachine.next_tick do
        response = "HTTP/#{http_version.join('.')} #{code} #{status}"

        headers = {} if headers.empty?
        headers[:content_length] = body.bytesize if headers[:content_length].nil?
        headers[:access_control_allow_origin] = @request.origin if !@request.origin.nil?

        formatted_headers = format_response_headers(headers)

        response << "\r\n" << formatted_headers
        response << "\r\n\r\n"
        response << body

        send_data(response)
      end
    end

    private def receive_payload_data(data)
      @payload << data
    end

    private def start_request
      clear_request
      clear_multipart
      clear_payload
    end

    private def finish_request
    end

    private def start_payload
      if multipart?
        start_multipart_payload
      else
        start_inline_payload
      end
    end

    private def clear_request
      @request = Request.new
    end

    private def process_headers
      headers = {}

      @parser.headers.each_pair do |key, value|
        normalized_key = key.strip.downcase
        headers[normalized_key] = value
      end

      @request.headers = headers

      @request.remote_ip = remote_ip

      @request.origin = @request.headers['origin']
    end

    private def payload?
      return @has_payload if !@has_payload.nil?

      @has_payload = PAYLOAD_METHODS.include?(@parser.http_method.to_s.downcase)

      @has_payload
    end

    private def request_method?(method)
      @parser.http_method.to_s.downcase == method.to_s.downcase
    end

    private def clear_multipart
      @is_multipart = nil
    end

    private def multipart?
      return @is_multipart if !@is_multipart.nil?

      content_type = @request.headers[CONTENT_TYPE_KEY]

      if content_type.nil? || content_type.empty?
        @is_multipart = false
      else
        @is_multipart = content_type.split(';').first.downcase == MULTIPART_CONTENT_TYPE
      end

      @is_multipart
    end

    private def clear_payload
      @has_payload = nil
      @payload = nil
    end

    private def start_multipart_payload
      content_type = @request.headers[CONTENT_TYPE_KEY]
      multipart_boundary = MultipartParser::Reader.extract_boundary_value(content_type)

      @payload = Payloads::MultipartPayload.new(self, file_manager, multipart_boundary)
    end

    private def start_inline_payload
      @payload = Payloads::InlinePayload.new(self, file_manager)
    end

    private def handle_options_request
      cors_headers = {
        access_control_allow_methods: 'PUT, POST',
        access_control_allow_headers: 'accept, content-type',
      }

      respond(200, 'OK', cors_headers)
    end

    private def format_response_headers(headers = {})
      formatted_headers = []

      headers.each_pair do |key, value|
        formatted_key = key.to_s.strip.downcase.gsub(/[:_\- ]/, '-').squeeze('-').gsub(/[\s]+/, '')
        formatted_key = formatted_key.split('-').map { |s| s.capitalize }.join('-')

        formatted_headers << "#{formatted_key}: #{value}"
      end

      formatted_headers.join("\r\n")
    end
  end
end
