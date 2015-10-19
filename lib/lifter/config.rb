module Lifter
  class Config
    Webhook = Struct.new(:method, :url)

    def initialize(&definition)
      # Defaults
      @config = {
        host: '127.0.0.1'
      }

      instance_eval(&definition)
    end

    def get(key)
      key = key.to_sym

      raise ArgumentError.new('unknown key') if !@config.has_key?(key)

      @config[key]
    end

    def host(host)
      @config[:host] = host
    end

    def port(port)
      @config[:port] = port.to_i
    end

    def working_dir(path)
      @config[:working_dir] = path
    end

    def upload_hash_method(upload_hash_method)
      @config[:upload_hash_method] = upload_hash_method
    end

    def max_upload_size(max_upload_size)
      @config[:max_upload_size] = max_upload_size
    end

    def upload_prologue_size(upload_prologue_size)
      @config[:upload_prologue_size] = upload_prologue_size
    end

    def authorize_webhook(method, url)
      @config[:authorize_webhook] = Webhook.new(method, url)
    end

    def completed_webhook(method, url)
      @config[:completed_webhook] = Webhook.new(method, url)
    end
  end
end
