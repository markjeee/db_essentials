module Palmade
  module DbEssentials
    module Acts
      module PostCallback
        private

        def _post_callback(method, cb_response); cb_response; end
        def _pre_callback(method); true; end

        def callback_with_post_callback(method)
          # let's do a pre-callback if it exists
          pre_response = _pre_callback(method)

          # do only if pre_response returned true
          if pre_response
            callback_response = callback_without_post_callback(method)
          else
            callback_response = pre_response
          end

          # let's do a post-callback if any
          _post_callback(method, callback_response)
        end

        def self.included(base)
          base.class_eval do
            alias_method_chain :callback, :post_callback
          end
        end
      end
    end
  end
end
