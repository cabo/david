module David
  class Transcoding
    include Celluloid

    def initialize(app)
      @app = app
      @map = {}
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      map = @map[:default]
      response = @app.call(env)

      return response if map.nil?

      code, headers, body = response

      mapped_types = map.map do |key, value|
        Mime::Type.lookup_by_extension(key).to_s
      end

      p mapped_types

#     mt = media_type(headers['Content-Type'])
        
      [code, headers, body]
    end

    def register(controller, options)
#     name = controller.controller_name
      @map.merge!(options)
      p @map
    end

    private

    def media_type(content_type)
      content_type.split(';').first
    end
  end
end
