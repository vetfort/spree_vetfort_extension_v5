# frozen_string_literal: true
# VetfortExtensionV5::Imports::ImportTableComponent
module VetfortExtensionV5
  module Imports
    class ImportTableComponent < ApplicationComponent
      attr_reader :import

      def initialize(import:)
        @import = import
      end

      def invalid_mapping?(mapped_col)
        mapped_col.present? && !valid_fields.include?(mapped_col)
      end

      def column_badge_class(mapped_col)
        invalid_mapping?(mapped_col) ? 'bg-warning' : 'bg-success'
      end

      def help_bubble(text)
        helpers.help_bubble(text)
      end

      def select_options_for(mapped_col)
        (Spree::VetfortExtensionV5::ProductImport::DEFAULT_FIELDS - import.field_mapping.values).map { |f| [f.humanize, f] } +
        [[mapped_col.humanize, mapped_col]].uniq
      end

      def field_type_for(initial_col)
        import.field_mapping[initial_col]
      end

      private

      def valid_fields
        Spree::VetfortExtensionV5::ProductImport::DEFAULT_FIELDS.map(&:to_s)
      end
    end
  end
end
