## AI-searchable Product Attributes via Structured Tags

This document describes how to make products AI-searchable using **structured, namespaced tags**, plus a small mapping layer and validations.

Core ideas:

- Use tags with the prefix `ai_searchable:` as the **canonical source of AI attributes**.
- Parse these tags into a **strongly typed attributes hash** (virtual properties) for each product.
- Make the future `ProductSearch` LLM tool depend only on those attributes and price/availability.
- Enforce correctness with **validation + whitelists** on `ActsAsTaggableOn::Tag`.

---

### 1. Tag schema for AI

We reserve tags starting with `ai_searchable:` purely for AI/search logic.

**General format**

- `ai_searchable:<dimension>:<value_slug>`

Where:

- `<dimension>` is one of a fixed set:
  - `species`, `format`, `diet`, `problem`, `brand`
- `<value_slug>` is a lowercase, snake_case value (no spaces, ASCII only).

**Example for a product “Royal Canin dry vet diet for dog skin problems”**

Attached tags on the product:

- `ai_searchable:species:dog`
- `ai_searchable:format:dry`
- `ai_searchable:diet:vet`
- `ai_searchable:problem:skin`
- `ai_searchable:brand:royal_canin`

These are standard `ActsAsTaggableOn` tags, just following a strict naming convention.

---

### 2. Recommended whitelists per dimension

Keep these in a Ruby constant or YAML configuration.

**species**

- `dog`, `cat`, `parrot`, `rodent`, `other`

**format** (food/product format)

- `dry`, `wet`, `treat`, `supplement`

**diet**

- `normal`, `premium`, `super_premium`, `vet` (therapeutic diet)

**problem**

Examples (extend as needed):

- `skin`
- `renal`
- `gi`
- `urinary`
- `joints`
- `allergy`
- `weight`
- `liver`
- `immune`
- `behavior` (stress/anxiety)
- `cancer`

**brand**

- `royal_canin`, `vet_expert`, `mr_bandit`, `piper_adult`, etc.
- Slug form; display name is derived later.

The key: **AI-facing values are explicit and finite**, not arbitrary free text.

---

### 3. Validation and normalization on `ActsAsTaggableOn::Tag`

We decorate `ActsAsTaggableOn::Tag` to:

1. Normalize tag names (strip, downcase, replace spaces).
2. Validate only `ai_searchable:` tags against a whitelist.
3. Expire AI-related cache on changes.

Example decorator:

```ruby
# config/initializers/acts_as_taggable_on_tag_decorator.rb (example path)

module Decorators
  module ActsAsTaggableOn
    module TagDecorator
      AI_PREFIX = "ai_searchable".freeze

      AI_WHITELIST = {
        "species" => %w[dog cat parrot rodent other],
        "format"  => %w[dry wet treat supplement],
        "diet"    => %w[normal premium super_premium vet],
        "problem" => %w[skin renal gi urinary joints allergy weight liver immune behavior cancer],
        # brand is often open-ended; you can choose to skip brand whitelist or manage it separately
      }.freeze

      def self.prepended(base)
        base.before_validation :normalize_name
        base.validate :validate_ai_searchable_tag
        base.after_commit :expire_ai_consultant_cache
      end

      private

      def normalize_name
        return if name.blank?

        normalized = name.strip
        normalized = normalized.downcase
        normalized = normalized.gsub(/\s+/, "_")
        self.name = normalized
      end

      def validate_ai_searchable_tag
        return unless name&.start_with?("#{AI_PREFIX}:")

        segments = name.split(":")

        # Expect: ai_searchable:<dimension>:<value_slug>
        unless segments.size == 3
          errors.add(:name, "has invalid ai_searchable format")
          return
        end

        _, dimension, value = segments

        allowed_values = AI_WHITELIST[dimension]

        # If we have a whitelist for this dimension, enforce it.
        if allowed_values && !allowed_values.include?(value)
          errors.add(:name, "has invalid value '#{value}' for dimension '#{dimension}'")
        end
      end

      def expire_ai_consultant_cache
        Rails.cache.delete("ai_consultant:available_tags")
      end
    end
  end
end

::ActsAsTaggableOn::Tag.prepend Decorators::ActsAsTaggableOn::TagDeco
rator
```
**Notes:**

- Non-AI tags (`!name.start_with?("ai_searchable:")`) are not restricted by this validator.
- For `brand`, you can:
  - Allow any slug (`ai_searchable:brand:*`) by skipping whitelist for `brand`, or
  - Maintain a dynamic whitelist if you want strict control.

---

### 4. `ProductAttributes` service – virtual attributes from tags

This service converts a product’s `ai_searchable:*` tags into a clean Ruby hash.

**Expected output** for a product like “Royal Canin dry vet diet for dog skin problems”:

```ruby
{
  species: :dog,
  food_format: :dry,
  diet_class: :vet,
  problems: [:skin],
  brand: "Royal Canin"
}
```

**Example implementation:**

```ruby
# app/services/product_attributes.rb

class ProductAttributes
  AI_PREFIX = "ai_searchable".freeze

  attr_reader :product

  def initialize(product)
    @product = product
  end

  def to_h
    {
      species:     extract_single_enum("species"),
      food_format: extract_single_enum("format"),
      diet_class:  extract_single_enum("diet"),
      problems:    extract_multi_enum("problem"),
      brand:       extract_brand
    }
  end

  private

  def ai_tags
    @ai_tags ||= Array(product.tag_list).map(&:to_s).select do |tag|
      tag.start_with?("#{AI_PREFIX}:")
    end
  end

  def extract_single_enum(dimension)
    tag = ai_tags.find { |t| t.start_with?("#{AI_PREFIX}:#{dimension}:") }
    return nil unless tag

    _, _, value = tag.split(":")
    value&.to_sym
  end

  def extract_multi_enum(dimension)
    ai_tags
      .select { |t| t.start_with?("#{AI_PREFIX}:#{dimension}:") }
      .map { |t| t.split(":").last.to_sym }
      .uniq
  end

  def extract_brand
    tag = ai_tags.find { |t| t.start_with?("#{AI_PREFIX}:brand:") }
    return nil unless tag

    _, _, slug = tag.split(":")

    # Simple conversion from slug to display name:
    slug.tr("_", " ").split.map(&:capitalize).join(" ")
  end
end
```

You can later enrich extract_brand (e.g., map slug to a known Brand model or constant).

---

5. Using these attributes in the ProductSearch tool
The (future) ProductSearch tool will:

- Define a structured function for the LLM:

  - species: "dog" | "cat" | "parrot" | "rodent" | "other"
  - food_format: "dry" | "wet" | "treat" | "supplement"
  - diet_class: "normal" | "premium" | "super_premium" | "vet"
  - problems: ["skin", "renal", ...]
  - brand: free text (name or slug)
  - max_price: number (optional)
  - limit: integer (default 10)

- Translate those arguments to tag-based filters using the ai_searchable: convention.

Example filtering logic (simple version using ActsAsTaggableOn):

```ruby
scope = Spree::Product.active

if species.present?
  scope = scope.tagged_with("ai_searchable:species:#{species}", any: true)
end

if food_format.present?
  scope = scope.tagged_with("ai_searchable:format:#{food_format}", any: true)
end

if diet_class.present?
  scope = scope.tagged_with("ai_searchable:diet:#{diet_class}", any: true)
end

Array(problems).each do |problem|
  scope = scope.tagged_with("ai_searchable:problem:#{problem}", any: true)
end

if brand.present?
  brand_slug = brand.to_s.downcase.gsub(/\s+/, "_")
  scope = scope.tagged_with("ai_searchable:brand:#{brand_slug}", any: true)
end

if max_price.present?
  scope = scope.joins(:master).joins(:prices)
               .where("spree_prices.amount <= ?", max_price)
end

products = scope.limit(limit || 10)
```

The tool then returns JSON like:

```rb
[
  {
    "id": 123,
    "name": "Royal Canin Veterinary Diet Skin Care",
    "price": "800.00 MDL",
    "url": "/products/royal-canin-skin-care-dog-dry",
    "species": "dog",
    "food_format": "dry",
    "diet_class": "vet",
    "problems": ["skin"],
    "brand": "Royal Canin"
  }
]
```

For the LLM:

- It never has to guess tag strings.
- It only picks from documented enums; your Ruby code knows how to translate those to actual tag filters.

---

6. Role of taxons and properties in this design

With this tag-centric approach:

Taxons

- Main role: navigation, storefront categories, merchandising, SEO.
- Optional: help you decide which ai_searchable:* tags to assign when editing products.
- Not required for the LLM to find products.

Properties

- Main role: detailed structured fields (composition, country, life stage, etc.).
- Optional:
  - Use them for admin hints during tagging.
  - Map outputs from import LLM tools (PropertiesFetch, etc.) into ai_searchable:* tags.

But the main contract for AI tools is:

- ProductAttributes built from ai_searchable:* tags.
- ProductSearch using those attributes + price/availability to query products.


7. Summary
- Use namespaced AI tags (ai_searchable:*) as the stable, explicit interface between product data and AI logic.
- Enforce a schema + whitelist per dimension via ActsAsTaggableOn::Tag decorator.
- Implement a small ProductAttributes service to convert tags to a virtual attributes hash.
- Make ProductSearch only depend on those attributes (and price/stock), not on raw Russian category names.
- Taxons and properties remain important for navigation and admin UX, but they no longer have to carry AI semantics directly.
