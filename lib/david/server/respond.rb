require 'david/server/constants'
require 'david/server/mapping'
require 'david/server/utility'

module David
  class Server
    module Respond
      include Constants
      include Mapping
      include Utility

      def respond(request, env = nil)
        block_enabled = @block && request.get?

        if block_enabled
          # Fail if m set.
          if request.block.more && !request.multicast?
            return error(request, 4.05)
          end
        end

        return error(request, 5.05) if request.proxy?

        env ||= basic_env(request)

        code, headers, body = @app.call(env)

        # No error responses on multicast requests.
        return if request.multicast? && !(200..299).include?(code)

        ct = headers[HTTP_CONTENT_TYPE]
        body = body_to_string(body)

        body.close if body.respond_to?(:close)

        if @cbor && ct == 'application/json'
          begin
            body = body_to_cbor(body)
            ct = CONTENT_TYPE_CBOR
          rescue JSON::ParserError
          end
        end

        # No response on request for non-existent block.
        return if block_enabled && !request.block.included_by?(body)

        cf    = CoAP::Registry.convert_content_format(ct)
        etag  = etag_to_coap(headers, 4)
        loc   = location_to_coap(headers)
        ma    = max_age_to_coap(headers)
        mcode = code_to_coap(code)
        size  = headers[HTTP_CONTENT_LENGTH].to_i

        # App returned cf different from accept
        return error(request, 4.06) if request.accept && request.accept != cf

        response = initialize_response(request, mcode)

        response.options[:content_format] = cf
        response.options[:etag] = etag
        response.options[:location_path] = loc unless loc.nil?
        response.options[:max_age] = ma.to_i unless ma.nil?

        if @observe && handle_observe(request, env, etag)
          response.options[:observe] = 0
        end

        if block_enabled
          block = request.block.dup
          block.set_more!(body)

          response.payload = block.chunk(body)
          response.options[:block2] = block.encode
#         response.options[:size2]  = size if size != 0
        else
          response.payload = body
        end

        [response, {}]
      end

      private

      def basic_env(request)
        m = request.message

        {
          REMOTE_ADDR       => request.host,
          REMOTE_PORT       => request.port.to_s,
          REQUEST_METHOD    => method_to_http(m.mcode),
          SCRIPT_NAME       => EMPTY_STRING,
          PATH_INFO         => path_encode(m.options[:uri_path]),
          QUERY_STRING      => query_encode(m.options[:uri_query])
                                 .gsub(/^\?/, ''),
          SERVER_NAME       => @host,
          SERVER_PORT       => @port.to_s,
          CONTENT_LENGTH    => m.payload.bytesize.to_s,
          CONTENT_TYPE      => EMPTY_STRING,
          HTTP_ACCEPT       => accept_to_http(request),
          RACK_VERSION      => [1, 2],
          RACK_URL_SCHEME   => RACK_URL_SCHEME_HTTP,
          RACK_INPUT        => StringIO.new(m.payload),
          RACK_ERRORS       => $stderr,
          RACK_MULTITHREAD  => true,
          RACK_MULTIPROCESS => true,
          RACK_RUN_ONCE     => false,
          RACK_LOGGER       => @logger,
          COAP_VERSION      => 1,
          COAP_MULTICAST    => request.multicast?,
          COAP_DTLS         => COAP_DTLS_NOSEC,
          COAP_DTLS_ID      => EMPTY_STRING,
        }
      end

      def error(request, mcode)
        [initialize_response(request, mcode), retransmit: false]
      end

      def handle_observe(request, env, etag)
        return unless request.get? && request.observe?

        if request.message.options[:observe] == 0
          observe.add(request, env, etag)
          true
        else
          observe.delete(request)
          false
        end
      end

      def initialize_response(request, mcode = 2.00)
        type = request.con? ? :ack : :non

        CoAP::Message.new \
          tt: type,
          mcode: mcode,
          mid: request.message.mid || SecureRandom.random_number(0xffff),
          token: request.token
      end

      def observe
        Celluloid::Actor[:observe]
      end
    end
  end
end
