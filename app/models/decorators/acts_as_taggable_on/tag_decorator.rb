module Decorators
  module ActsAsTaggableOn
    module TagDecorator
      def self.prepended(base)
        base.after_commit :expire_ai_consultant_cache
      end

      def expire_ai_consultant_cache
        Rails.cache.delete('ai_consultant:available_tags')
      end
    end
  end
end

::ActsAsTaggableOn::Tag.prepend Decorators::ActsAsTaggableOn::TagDecorator
