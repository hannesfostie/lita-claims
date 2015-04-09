require "lita"

module Lita
  module Handlers
    class Claims < Handler
      PROPERTY_OR_ENVIRONMENT = /[\w\-]+/

      route(/^claim\s(#{PROPERTY_OR_ENVIRONMENT.source})(?:\s(#{PROPERTY_OR_ENVIRONMENT.source}))?/i, :create, command: true, help: {
        "claim PROPERTY" => "To claim a property by the name PROPERTY"
      })

      route(/^who claimed\s(#{PROPERTY_OR_ENVIRONMENT.source})(?:\s(#{PROPERTY_OR_ENVIRONMENT.source}))?/i, :exists?, command: true, help: {
        "who claimed PROPERTY" => "To see who claimed a property by the name PROPERTY"
      })

      route(/^unclaim\s(#{PROPERTY_OR_ENVIRONMENT.source})(?:\s(#{PROPERTY_OR_ENVIRONMENT.source}))?/i, :destroy, command: true, help: {
        "unclaim PROPERTY" => "To remove your claim from a property by the name PROPERTY"
      })

      route(/^force\sunclaim\s(#{PROPERTY_OR_ENVIRONMENT.source})(?:\s(#{PROPERTY_OR_ENVIRONMENT.source}))?/i, :force_destroy, command: true, help: {
        "force unclaim PROPERTY" => "To remove a claim by someone else from a property by the name PROPERTY"
      })

      http.get "/available/:property/:requester(/:environment)", :available

      def available(request, response)
        property = request.env['router.params'][:property]
        environment = request.env['router.params'][:environment]
        environment_string = " (#{environment})" if environment
        requester = request.env['router.params'][:requester]
        claimer = Claim.read(property, environment)
        if Claim.exists?(property, environment) && claimer != requester
          # forbidden
          response.status = 403
          response.headers["Content-Type"] = "application/json"
          response.body = {claimer: claimer}
          target = Source.new(room: '#devs')
          robot.send_message(target, "#{requester} tried deploying #{property}#{environment_string} but it has been claimed by #{claimer}.")
        else
          # OK
          response.status = 200
          response.headers["Content-Type"] = "application/json"
          response.body = {}
        end
      end

      def create(response)
        claimer = response.message.source.user.name
        property, environment = response.matches.first
        environment ||= 'default'
        environment_string = " (#{environment})" if environment != 'default'
        if property && !Claim.exists?(property, environment)
          Claim.create(property, claimer, environment)
          reply = "#{property}#{environment_string} was claimed by #{claimer}."
        else
          existing_claimer = Claim.read(property, environment)
          reply = "Could not claim #{property}#{environment_string} - already claimed by #{existing_claimer}."
        end
        response.reply(reply)
      end

      def exists?(response)
        property, environment = response.matches.first
        environment ||= 'default'
        environment_string = " (#{environment})" if environment != 'default'
        if property && Claim.exists?(property, environment)
          claimer = Claim.read(property, environment)
          reply = "#{property}#{environment_string} is currently claimed by #{claimer}."
        else
          reply = "#{property}#{environment_string} has not been claimed."
        end
        response.reply(reply)
      end

      def destroy(response)
        unclaimer = response.message.source.user.name
        property, environment = response.matches.first
        environment ||= 'default'
        environment_string = " (#{environment})" if environment != 'default'
        if property && Claim.exists?(property, environment)
          claimer = Claim.read(property, environment)
          if claimer == unclaimer
            Claim.destroy(property, environment)
            reply = "#{property}#{environment_string} is no longer claimed."
          else
            reply = "#{property}#{environment_string} is currently claimed by #{claimer}. Use the `force unclaim` command when you are sure to unclaim the property."
          end
        else
          reply = "#{property}#{environment_string} has not yet been claimed."
        end
        response.reply(reply)
      end

      def force_destroy(response)
        property, environment = response.matches.first
        environment ||= 'default'
        environment_string = " (#{environment})" if environment != 'default'
        if property && Claim.exists?(property, environment)
          Claim.destroy(property, environment)
          reply = "#{property}#{environment_string} is no longer claimed."
        else
          reply = "#{property}#{environment_string} has not yet been claimed."
        end
        response.reply(reply)
      end
    end

    Lita.register_handler(Claims)
  end
end
