module Decorators
  module ActsAsTaggableOn
    module TagDecorator
      def self.prepended(base)
        base.before_validation :normalize_ai_tag
        base.validate :validate_ai_tag
        base.after_commit :expire_ai_consultant_cache
      end

      private

      def normalize_ai_tag
        return unless AiSearchableTag.ai?(name)

        self.name = AiSearchable::TagFormat.normalize_value(name)
      end

      def validate_ai_tag
        return unless AiSearchableTag.ai?(name)

        ai = AiSearchableTag.new(raw_name: name)
        return if ai.valid?

        ai.errors.full_messages.each do |msg|
          errors.add(:name, msg)
        end
      end

      def expire_ai_consultant_cache
        Rails.cache.delete('ai_consultant:available_tags')
      end
    end
  end
end

::ActsAsTaggableOn::Tag.prepend Decorators::ActsAsTaggableOn::TagDecorator
