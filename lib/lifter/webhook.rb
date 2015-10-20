require 'http'

module Lifter
  class Webhook
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

    def params=(params)
      @params = params
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
