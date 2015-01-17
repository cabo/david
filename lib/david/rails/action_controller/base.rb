class ActionController::Base
  def self.discoverable(options)
    discovery_actor.register(self, options)
  end

  def self.transcodable(options)
    transcoding_actor.register(self, options)
  end

  protected

  def self.discovery_actor
    Celluloid::Actor[:discovery]
  end

  def self.transcoding_actor
    Celluloid::Actor[:transcoding]
  end
end
