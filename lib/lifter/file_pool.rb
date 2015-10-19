module Lifter
  class FilePool
    def initialize
      @files = {}
    end

    def get(file_id)
      @files[file_id]
    end

    def add(file_id, file, opts = {})
      file_upload = FileUpload.new(file, opts)
      @files[file_id] = file_upload
    end

    def remove(file_id)
      @files.delete(file_id)
    end
  end
end
