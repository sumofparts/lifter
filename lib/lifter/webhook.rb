require 'http'

module Lifter
  class Webhook
    attr_reader :url, :method, :headers, :params

    def initialize(endpoint)
      @url = endpoint.url
      @method = endpoint.method
      @headers = {}
      @params = {}
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
      http_stub = HTTP.headers(@headers)

      case @method.to_sym
      when :get
        http_stub.get(@url, params: @params)
      when :post
        http_stub.post(@url, form: @params)
      when :put
        http_stub.put(@url, form: @params)
      else
        raise StandardError.new('unsupported http method in webhook')
      end
    end
  end
end
