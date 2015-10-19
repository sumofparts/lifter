require 'fileutils'
require 'digest/sha1'
require 'digest/sha2'
require 'digest/md5'

module Lifter
  class FileUpload
    DEFAULT_PROLOGUE_SIZE = 10 * 1024

    attr_reader :prologue, :original_request, :original_name, :param

    def initialize(file, opts = {})
      @file = file

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
      @file.close
    end

    def rm
      FileUtils.rm(full_path)
    end

    def mv(new_path)
      FileUtils.mv(full_path, new_path)
    end

    def full_path
      File.expand_path(@file.path)
    end

    def hash
      @hash.hexdigest
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
