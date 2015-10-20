require 'fileutils'
require 'digest/sha1'
require 'digest/sha2'
require 'digest/md5'

module Lifter
  class FileUpload
    DEFAULT_PROLOGUE_SIZE = 10 * 1024

    attr_reader :prologue, :original_request, :original_name, :param

    def initialize(file, opts = {})
      @mutex = Mutex.new

      @file = file
      @path = file.path

      @authorized = false
      @pending_authorization = false

      @hash = setup_hash(opts[:hash_method])

      @prologue_limit = opts[:prologue_size] || DEFAULT_PROLOGUE_SIZE
      @prologue = ''

      @original_request = opts[:original_request]
      @original_name = opts[:original_name]
      @param = opts[:param]
    end

    def write(data)
      @file.write(data)

      @hash << data

      if @prologue.length < @prologue_limit
        @prologue << data[0, @prologue_limit - @prologue.length]
      end
    end

    def flush
      @file.flush
    end

    def close
      @file.close if !@file.closed?
    end

    def rm
      FileUtils.rm(full_path)
      @path = nil
    end

    def mv(new_path)
      FileUtils.mv(full_path, new_path)
      @path = new_path
    end

    def full_path
      File.expand_path(@path)
    end

    def hash
      @hash.hexdigest
    end

    def authorize
      @mutex.synchronize do
        @authorized = true
      end
    end

    def pending_authorization
      @mutex.synchronize do
        @pending_authorization = true
      end
    end

    def pending_authorization?
      pending = false

      @mutex.synchronize do
        pending = @pending_authorization == true
      end

      pending
    end

    def authorized?
      authorized = false

      @mutex.synchronize do
        authorized = @authorized == true
      end

      authorized
    end

    private def setup_hash(hash_type)
      case hash_type
      when :md5
        Digest::MD5.new
      when :sha1
        Digest::SHA1.new
      when :sha256
        Digest::SHA256.new
      when :sha512
        Digest::SHA512.new
      else
        Digest::MD5.new
      end
    end
  end
end
