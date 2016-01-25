module Rack
  module Handler
    class David
      def self.run(app, options={})
        g = Celluloid::Supervision::Container.run!

        g.supervise(as: :server, type: ::David::Server, args: [app, options])
        g.supervise(as: :gc, type: ::David::GarbageCollector)

        unless options[:Observe] == 'false'
          g.supervise(as: :observe, type: ::David::Observe)
        end

        warn "COAP_ONLY: #{coap_only?.inspect}"
        unless coap_only?
          default_options = {
            :Host    => "0.0.0.0",
            :Port    => 3000,
            :quiet   => false
          }
          options = default_options.merge(options)

          app = Rack::CommonLogger.new(app, STDOUT) unless options[:quiet]
          ENV['RACK_ENV'] = options[:environment].to_s if options[:environment]

          warn "REEL OPTIONS: #{options.inspect}"

          g.supervise(as: :reel_rack_server, type: ::Reel::Rack::Server, args: [app, options])
        end

        begin
          Celluloid::Actor[:server].run
        rescue Interrupt
          Celluloid.logger.info 'Terminated'
          Celluloid.logger = nil
          g.terminate
        end
      end

      def self.valid_options
        host, port = AppConfig::DEFAULT_OPTIONS.values_at(:Host, :Port)

        {
          'Block=BOOLEAN'     => 'Support for blockwise transfer (default: true)',
          'CBOR=BOOLEAN'      => 'Transparent JSON/CBOR conversion (default: false)',
          'DefaultFormat=F'   => 'Content-Type if CoAP accept option on request is undefined',
          'Host=HOST'         => "Hostname to listen on (default: #{host})",
          'Log=LOG'           => 'Change logging (debug|none)',
          'Multicast=BOOLEAN' => 'Multicast support (default: true)',
          'Observe=BOOLEAN'   => 'Observe support (default: true)',
          'Port=PORT'         => "Port to listen on (default: #{port})"
        }
      end

      
      def self.coap_only?
        false                   # XXX
        # ::Rack::Handler::rails_coap_only
      end
    end

    register(:david, David)
  end
end
