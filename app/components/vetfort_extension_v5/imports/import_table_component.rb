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

      private

      def valid_fields
        Spree::VetfortExtensionV5::ProductImport::DEFAULT_FIELDS.map(&:to_s)
      end
    end
  end
end
