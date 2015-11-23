require 'http'

module Lifter
  class Webhook
    # Courtesy of: http://dev.mensfeld.pl/2012/01/converting-nested-hash-into-http-url-params-hash-version-in-ruby/
    module ParamNester
      def self.encode(value, key = nil, out_hash = {})
        case value
        when Hash
          value.each { |k,v| encode(v, append_key(key, k), out_hash) }
          out_hash
        when Array
          value.each { |v| encode(v, "#{key}[]", out_hash) }
          out_hash
        when nil
          ''
        else
          out_hash[key] = value
          out_hash
        end
      end

      def self.append_key(root_key, key)
        root_key.nil? ? :"#{key}" : :"#{root_key}[#{key.to_s}]"
      end
    end

    RETRY_CODES = [500, 502, 503, 504]
    RETRY_LIMIT = 3

    attr_reader :url, :method, :headers, :params

    def initialize(endpoint)
      @url = endpoint.url
      @method = endpoint.method
      @headers = {}
      @params = {}

      @retry_count = 0
      @retry_limit = RETRY_LIMIT

      @on_success = nil
      @on_failure = nil
    end

    def headers=(headers)
      @headers = headers
    end

    def params=(params = {})
      @params = ParamNester.encode(params)
    end

    def on_success(&block)
      @on_success = block
    end

    def on_failure(&block)
      @on_failure = block
    end

    def deliver
      begin
        start_delivery
      rescue Errors::WebhookFailed => e
        @on_failure.call if !@on_failure.nil?
      end

      @on_success.call if !@on_success.nil?
    end

    private def start_delivery
      begin
        response = finish_delivery
      rescue StandardError => e
        raise Errors::WebhookFailed.new
      end

      return if response.code == 200

      if RETRY_CODES.include?(response.code) && @retry_count < @retry_limit
        @retry_count += 1
        start_delivery
      else
        raise Errors::WebhookFailed.new
      end
    end

    private def finish_delivery
      http_stub = HTTP.headers(@headers)

      case @method.to_sym
      when :get
        http_stub.get(@url, params: @params)
      when :post
        http_stub.post(@url, form: @params)
      when :put
        http_stub.put(@url, form: @params)
      else
        raise Errors::InvalidWebhookMethod.new
      end
    end
  end
end
