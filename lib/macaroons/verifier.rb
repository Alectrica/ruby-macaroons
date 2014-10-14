require 'macaroons/errors'

module Macaroons
  class Verifier
    attr_accessor :predicates
    attr_accessor :callbacks

    def initialize
      @predicates = []
      @callbacks = []
    end

    def satisfy_exact(predicate)
      raise ArgumentError, 'Must provide predicate' unless predicate
      @predicates << predicate
    end

    def satisfy_general(callback)
      raise ArgumentError, 'Must provide callback' unless callback
      @callbacks << callback
    end

    def verify(macaroon: nil, key: nil, discharge_macaroons: nil)
      raise ArgumentError, 'Macaroon and Key required' if macaroon.nil? || key.nil?

      compare_macaroon = Macaroons::Macaroon.new(key: key, identifier: macaroon.identifier, location: macaroon.location)

      verify_caveats(macaroon, compare_macaroon, discharge_macaroons)

      raise SignatureMismatchError, 'Signatures do not match.' unless signatures_match(macaroon.signature, compare_macaroon.signature)

      return true
    end

    private

    def verify_caveats(macaroon, compare_macaroon, discharge_macaroons)
      for caveat in macaroon.caveats
        if caveat.first_party?
          caveat_met = verify_first_party_caveat(caveat, compare_macaroon)
        else
          caveat_met = verify_third_party_caveat(caveat, compare_macaroon, discharge_macaroons)
        end
        raise CaveatUnsatisfiedError, "Caveat not met. Unable to satisfy: #{caveat.caveat_id}" unless caveat_met
      end
    end

    def verify_first_party_caveat(caveat, compare_macaroon)
      caveat_met = false
      if @predicates.include? caveat.caveat_id
        caveat_met = true
      else
        @callbacks.each do |callback|
          caveat_met = true if callback.call(caveat.caveat_id)
        end
      end
      compare_macaroon.add_first_party_caveat(caveat.caveat_id) if caveat_met

      return caveat_met
    end

    def verify_third_party_caveat(caveat, compare_macaroon, discharge_macaroons)
      # TODO
      raise NotImplementedError
    end

    def signatures_match(a, b)
      # Constant time compare, taken from Rack
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")

      r, i = 0, -1
      b.each_byte { |v| r |= v ^ l[i+=1] }
      r == 0
    end

  end
end
