class ProductRowImporter < ApplicationService
  def call(row:)
    product_data = yield extract_product_data(row:)
    product = yield create_product(product_data:)
    product_with_translations = yield localize_product(product:, product_data:)
    product_with_taxons = yield add_taxons_to_product(product_with_translations, product_data:)
    product_with_properties = yield add_properties_to_product(product_with_taxons, product_data:)
    product_with_options = yield add_options_to_product(product_with_properties, product_data:)
    product_with_tags = yield add_tags_to_product(product_with_options, product_data:)
    product_with_import = yield assign_product_to_import(product_with_tags, row:)
    product_with_image = yield add_image_to_product(product_with_import, product_data:)
    mark_row_as_imported(row:)

    product_with_import
  end

  private

  def extract_product_data(row:)
    LLMAssistants::ProductDataExtractor.new.call(row:)
  end

  def create_product(product_data:)
    with_rescue do
      product_attributes = product_data.product_attributes
      store = Spree::Store.default

      variant = Spree::Variant.find_by(sku: product_data.sku)
      product = variant ? variant.product : Spree::Product.new(product_attributes)

      product.assign_attributes(product_attributes)
      product.save!

      product.stores << store unless product.persisted? || product.stores.include?(store)

      product.reload
    end
  end

  def localize_product(product:, product_data:)
    with_rescue do
      product.translations.find_or_initialize_by(locale: :ro).update!(
        name:             product_data.name(:ro),
        description:      product_data.description(:ro),
        meta_title:       product_data.meta_title(:ro),
        meta_description: product_data.meta_description(:ro),
        meta_keywords:    product_data.meta_keywords(:ro)
      )

      product.translations.find_or_initialize_by(locale: :ru).update!(
        name:             product_data.name(:ru),
        description:      product_data.description(:ru),
        meta_title:       product_data.meta_title(:ru),
        meta_description: product_data.meta_description(:ru),
        meta_keywords:    product_data.meta_keywords(:ru)
      )

      product.reload
    end
  end

  def add_taxons_to_product(product, product_data:)
    with_rescue do
      new_taxons_set = product_data.taxons_scope.to_a | product.taxons.to_a
      product.taxons = new_taxons_set
      product.save!

      product.reload
    end
  end

  def add_properties_to_product(product, product_data:)
    with_rescue do
      product_data.properties_scope.each do |property, values|
        %i[ru ro].each do |locale|
          I18n.with_locale(locale) do
            pr_prop = product.product_properties.find_or_initialize_by(property: property)
            pr_prop.value = values[locale]
            pr_prop.save!
          end
        end
      end

      product.reload
    end
  end

  def add_options_to_product(product, product_data:)
    with_rescue do
      # options_map = product_data.options_scope

      # product.option_types |= options_map.keys
      # product.save! if product.changed?

      # return product unless options_map.present?

      # option_values_lists = options_map.values.map { |v| Array(v) }
      # combinations = option_values_lists.shift.product(*option_values_lists)

      # combinations.each do |values_combo|
      #   values_combo = Array(values_combo).flatten
      #   sorted_ids = values_combo.map(&:id).sort
      #   existing = product.variants.detect do |v|
      #     v.option_values.map(&:id).sort == sorted_ids
      #   end
      #   next if existing

      #   product.variants.create!(
      #     option_values: values_combo,
      #     price: product.master.price,
      #     sku: nil
      #   )
      # end

      product.reload
    end
  end


  def assign_product_to_import(product, row:)
    with_rescue do
      row.product = product
      row.save!

      product.reload
    end
  end

  # def add_image_to_product(product, product_data:)
  #   with_rescue do

  #     product_data.images.each do |image_url|
  #       image = ImageProcessor.call(image_url)
  #       product.images.attach(io: image, filename: 'image.png')
  #     end

  #     product.save!
  #     product.reload
  #   end
  # end

  # def add_image_to_product(product, product_data:)
  #   with_rescue do
  #     product_data.images.each do |image_url|
  #       file = ImageProcessor.new.call(image_url)
  #       product.images.attach(
  #         io: file,
  #         filename: "#{SecureRandom.hex(6)}.png",
  #         content_type: "image/png"
  #       )
  #       file.close
  #       file.unlink
  #     end

  #     product.save!
  #     product.reload
  #   end
  # end

  def add_image_to_product(product, product_data:)
    with_rescue do
      product_data.images.each do |image_url|
        file = ImageProcessor.new.call(image_url)

        Spree::Image.create!(
          viewable: product.master,
          attachment: {
            io: file,
            filename: "product-#{SecureRandom.hex(6)}.png",
            content_type: "image/png"
          },
          alt: product.name
        )
      ensure
        file.close unless file.closed?
        file.unlink rescue nil
      end

      product.reload
    end
  end

  def add_tags_to_product(product, product_data:)
    with_rescue do
      Spree::Tags::BulkAdd.call(tag_names: product_data.tags_scope, records: [product])

      product.reload
    end
  end

  def mark_row_as_imported(row:)
    with_rescue do
      row.import!
    end
  end
end
