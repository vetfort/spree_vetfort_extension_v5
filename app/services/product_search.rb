class ProductSearch
  attr_reader :species, :format, :diet, :problems, :brand, :max_price, :limit

  def initialize(species: nil, format: nil, diet: nil, problems: nil, brand: nil, max_price: nil, limit: nil)
    @species   = Array.wrap(species).compact_blank
    @format    = format
    @diet      = diet
    @problems  = Array.wrap(problems).compact_blank
    @brand     = brand
    @max_price = max_price
    @limit     = limit
  end

  def call
    base_scope
      .then { |s| filter_species(s) }
      .then { |s| filter_format(s) }
      .then { |s| filter_diet(s) }
      .then { |s| filter_problems(s) }
      .then { |s| filter_brand(s) }
      .then { |s| filter_max_price(s) }
      .then { |s| apply_limit(s) }
      .distinct
  end

  private

  def base_scope
    Spree::Product.includes(master: :prices)
  end

  def apply_limit(scope)
    return scope if limit.blank?

    scope.limit(limit)
  end

  def build_tags(dimension, values)
    Array.wrap(values).compact_blank.map do |value|
      AiSearchable::TagFormat.build(dimension, value)
    end
  end

  def filter_species(scope)
    return scope if species.blank?

    scope.tagged_with(build_tags("species", species), any: true)
  end

  def filter_format(scope)
    return scope if format.blank?

    scope.tagged_with(AiSearchable::TagFormat.build("format", format))
  end

  def filter_diet(scope)
    return scope if diet.blank?

    scope.tagged_with(AiSearchable::TagFormat.build("diet", diet))
  end

  def filter_problems(scope)
    return scope if problems.blank?

    scope.tagged_with(build_tags("problem", problems), any: true)
  end

  def filter_brand(scope)
    return scope if brand.blank?

    scope.tagged_with(AiSearchable::TagFormat.build("brand", brand))
  end

  def filter_max_price(scope)
    return scope if max_price.blank?

    scope
      .joins(master: :prices)
      .where(Spree::Price.arel_table[:amount].lteq(max_price))
  end
end
