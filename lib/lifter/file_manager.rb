require 'fileutils'

module Lifter
  class FileManager
    DEFAULT_HASH_METHOD = :md5

    SCRUB_HEADERS = %w(host content-type content-length accept accept-encoding accept-language
      connection)

    def initialize(config)
      @working_dir = resolve_working_dir(config.get(:working_dir))

      @authorize_webhook_endpoint = config.get(:authorize_webhook)
      @completed_webhook_endpoint = config.get(:completed_webhook)

      @work = ThreadPool.new(5)
      @webhooks = ThreadPool.new(5)
      @files = FilePool.new

      @upload_hash_method = config.get(:upload_hash_method) || DEFAULT_HASH_METHOD
      @upload_prologue_size = config.get(:upload_prologue_size)
    end

    def open_file(connection, file_id, file_param, file_name)
      @work.push(file_id) do
        file = File.open("#{@working_dir}/progress/#{file_id}", 'wb')

        file_opts = {
          hash_method: @upload_hash_method,
          prologue_size: @upload_prologue_size,
          original_name: file_name,
          original_request: connection.request,
          param: file_param
        }

        @files.add(file_id, file, file_opts)
      end
    end

    def write_file_data(connection, file_id, data)
      @work.push(file_id) do
        file = @files.get(file_id)
        file.write(data)

        if file.prologue.length >= @upload_prologue_size
          @webhooks.push(file_id) do
            webhook = create_authorize_webhook(connection, file)
            webhook.deliver
          end
        end
      end
    end

    def close_file(connection, file_id)
      @work.push(file_id) do
        file = @files.get(file_id)

        file.flush
        file.close

        file.mv("#{@working_dir}/completed/#{file_id}")

        @files.remove(file_id)

        # In the event the upload was too small for the prologue size to have been met previously,
        # ensure the authorize webhook is fired off before completed.
        if file.prologue.length < @upload_prologue_size
          @webhooks.push(file_id) do
            webhook = create_authorize_webhook(connection, file)
            webhook.deliver
          end
        end

        @webhooks.push(file_id) do
          webhook = create_completed_webhook(connection, file)
          webhook.deliver
        end
      end
    end

    def cancel_file(connection, file_id)
      @webhooks.clear(file_id)

      @work.push(file_id) do
        file = @files.get(file_id)

        file.close
        file.rm

        @files.remove(file_id)
      end
    end

    private def resolve_working_dir(working_dir)
      if working_dir.nil?
        Dir.pwd
      elsif working_dir[0, 1] == '/'
        working_dir
      else
        "#{Dir.pwd}/#{working_dir}"
      end
    end

    private def create_authorize_webhook(connection, file)
      webhook = Webhook.new(@authorize_webhook_endpoint)

      headers = file.original_request.headers.dup
      params = file.original_request.params.dup

      headers = clean_request_headers(headers)
      headers['x-upload-ip'] = file.original_request.remote_ip

      params[file.param] = {
        file_name: file.original_name,
        file_prologue: file.prologue.length
      }

      webhook.headers = headers
      webhook.params = params

      webhook.on_failure do
        connection.cancel
      end

      webhook
    end

    private def create_completed_webhook(connection, file)
      webhook = Webhook.new(@completed_webhook_endpoint)

      headers = file.original_request.headers.dup
      params = file.original_request.params.dup

      headers = clean_request_headers(headers)
      headers['x-upload-ip'] = file.original_request.remote_ip

      params[file.param] = {
        file_name: file.original_name,
        file_path: file.full_path,
        file_hash: file.hash
      }

      webhook.on_failure do
        connection.cancel
      end

      webhook
    end

    private def clean_request_headers(headers)
      SCRUB_HEADERS.each do |header_key|
        headers.delete(header_key)
      end

      headers
    end
  end
end
