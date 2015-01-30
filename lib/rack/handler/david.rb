module Rack
  module Handler
    class David
      def self.run(app, options={})
        options = ::David::AppConfig.new(options)

        @socket = Celluloid::IO::UDPSocket.new(::Socket::AF_INET6)
        @socket.bind(options[:Host], options[:Port])

        @mid_cache = {}

        args = [@socket, @mid_cache, app, options]

        begin
          ::David::Launcher.new(@socket, @mid_cache, app, options).run
        rescue Interrupt
          Celluloid.logger.info 'Terminated'
          Celluloid.logger = nil
        end
      end

      def self.valid_options
        host, port = DEFAULT_OPTIONS.values_at(:Host, :Port)

        {
          'Block=BOOLEAN'     => 'Support for blockwise transfer (default: true)',
          'CBOR=BOOLEAN'      => 'Transparent JSON/CBOR conversion (default: false)',
          'DefaultFormat=F'   => 'Content-Type if CoAP accept option on request is undefined',
          'Host=HOST'         => "Hostname to listen on",
          'Log=LOG'           => 'Change logging (debug|none)',
          'Multicast=BOOLEAN' => 'Multicast support (default: true)',
          'Observe=BOOLEAN'   => 'Observe support (default: true)',
          'Port=PORT'         => "Port to listen on",
          'Prefork=INT'       => 'Prefork (default: 0)'
        }
      end
    end

    register :david, David
  end
end
