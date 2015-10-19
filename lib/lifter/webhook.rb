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
      HTTP.headers(@headers).send(@method.to_sym, params: @params)
    end
  end
end
