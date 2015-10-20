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
    end

    def headers=(headers)
      @headers = headers
    end

    def params=(params)
      @params = params
    end

    def on_failure(&block)
      @on_failure = block
    end

    def deliver
      begin
        response = complete_delivery
      rescue StandardError => e
        raise Errors::WebhookFailed.new
      end

      return if response.code == 200

      if RETRY_CODES.include?(response.code) && @retry_count < @retry_limit
        @retry_count += 1
        deliver
      else
        raise Errors::WebhookFailed.new
      end
    end

    private def complete_delivery
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
