module David
  class Launcher
    def initialize(socket, mid_cache, app, options)
      @log = options[:Log]
      @prefork = options[:Prefork]

      args = [socket, mid_cache, app, options]

      g = Celluloid::SupervisionGroup.run!

      if @prefork > 0
        @prefork.times do |i|
          fork do
            @log.debug "Forked #{i}"
            Server.new(*args).run
          end
        end
      else
        g.supervise_as(:server, Server, *args)
        g.supervise_as(:observe, Observe) if options[:Observe] != false
        g.supervise_as(:gc, GarbageCollector)
      end

      @log.info "David #{VERSION} on #{RUBY_DESCRIPTION}"
      @log.info "Starting on [#{options[:Host]}]:#{options[:Port]}"

      self
    end

    def run
      if @prefork > 0
        Process.waitall
      else
        Celluloid::Actor[:server].run
      end
    end
  end
end
