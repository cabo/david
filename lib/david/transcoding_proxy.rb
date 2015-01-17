require 'david/transcoding'

module David
  class TranscodingProxy
    def initialize(app)
      Transcoding.supervise_as(:transcoding, app)
    end

    def call(env)
      Celluloid::Actor[:transcoding].call(env)
    end
  end
end
