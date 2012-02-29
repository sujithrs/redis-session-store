require 'redis'

# Redis session storage for Rails, and for Rails only. Derived from
# the MemCacheStore code, simply dropping in Redis instead.
#
# Options:
#  :key     => Same as with the other cookie stores, key name
#  :secret  => Encryption secret for the key
#  :host    => Redis host name, default is localhost
#  :port    => Redis port, default is 6379
#  :db      => Database number, defaults to 0. Useful to separate your session storage from other data
#  :key_prefix  => Prefix for keys used in Redis, e.g. myapp-. Useful to separate session storage keys visibly from others
#  :expire_after => A number in seconds to set the timeout interval for the session. Will map directly to expiry in Redis

module ActionDispatch
  module Session
      class RedisSessionStore < AbstractStore

        def initialize(app, options = {})
          super

          @default_options = {
            :namespace => 'rack:session'
          }.merge(options)

          @redis = Redis.new(@default_options)
        end

        private
          def prefixed(sid)
            "#{@default_options[:key_prefix]}:#{sid}"
          end

          def get_session(env, sid)
            sid ||= generate_sid
            begin
              data = @redis.get(prefixed(sid))
              session = data.nil? ? {} : Marshal.load(data)
            rescue Errno::ECONNREFUSED
              Rails.logger.warn("Session::RedisSessionStore#get_session: Connection refused")
              session = {}
            end
            [sid, session]
          end

          def set_session(env, sid, session_data, options)
            options ||= env['rack.session.options']
            expiry  = options[:expire_after] || nil
            if expiry
              @redis.setex(prefixed(sid), expiry, Marshal.dump(session_data))
            else
              @redis.set(prefixed(sid), Marshal.dump(session_data))
            end
            sid
          rescue Errno::ECONNREFUSED
            Rails.logger.warn("Session::RedisSessionStore#set_session: Connection refused")
            false
          end

          def destroy(env)
            if sid = current_session_id(env)
              @redis.del(prefixed(sid))
            end
          rescue Errno::ECONNREFUSED
            Rails.logger.warn("Session::RedisSessionStore#destroy: Connection refused")
          end

          def destroy_session(env, session_id, options)
            begin
              @redis.del(prefixed(session_id))
            rescue Errno::ECONNREFUSED
              Rails.logger.warn("Session::RedisSessionStore#destroy_session: Connection refused")
            end

            return nil if options[:drop]
            generate_sid
          end
      end
  end
end
