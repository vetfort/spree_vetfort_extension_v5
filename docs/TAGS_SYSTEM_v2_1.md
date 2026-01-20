# AI Searchable Product Attributes (v2.1)
## через структурированные namespaced теги + YAML конфиг + helpers

Этот документ описывает схему, как сделать товары удобными для AI поиска через LLM и убрать дублирование логики по всему проекту.

Ключевые элементы:

- Вся семантика для ИИ живет в тегах `ai_searchable:<dimension>:<value>`.
- YAML конфиг является единым источником правды.
- AiSearchableTag валидирует формат и значения.
- ActsAsTaggableOn::Tag только вызывает AiSearchableTag.
- ProductAttributes конвертирует теги в структурный hash.
- ProductSearch фильтрует товары по этим атрибутам.
- **Новый: AiSearchable::Tag.build и parse для централизации строк тегов.**
- **Новый: AiSearchable::Config.to_llm_schema для генерации схемы LLM-инструмента.**

---

## 1. Формат тегов

Строгий формат:

```
ai_searchable:<dimension>:<value>
```

Пример:

```
ai_searchable:species:dog
ai_searchable:format:dry
ai_searchable:diet:vet
ai_searchable:problem:skin
ai_searchable:brand:royal_canin
```

---

## 2. YAML конфиг

Файл: `config/ai_searchable.yml`

```yaml
ai_searchable:
  species:
    values:
      - dog
      - cat
      - parrot
      - rodent
      - other

  format:
    values:
      - dry
      - wet
      - treat
      - supplement

  diet:
    values:
      - normal
      - premium
      - super_premium
      - vet

  problem:
    values:
      - skin
      - renal
      - gi
      - urinary
      - joints
      - allergy
      - weight
      - liver
      - immune
      - behavior
      - cancer

  brand:
    allow_any: true
```

---

## 3. Центральный helper для тегов
### `AiSearchable::Tag`

Файл: `app/lib/ai_searchable/tag.rb`

```ruby
# frozen_string_literal: true

module AiSearchable
  module Tag
    AI_PREFIX = "ai_searchable"

    module_function

    def build(dimension, value)
      "#{AI_PREFIX}:#{dimension}:#{normalize_value(value)}"
    end

    def parse(tag_string)
      parts = tag_string.to_s.split(":")
      return nil unless parts.size == 3 && parts.first == AI_PREFIX

      {
        dimension: parts[1],
        value: parts[2]
      }
    end

    def normalize_value(value)
      value.to_s.strip.downcase.gsub(/\s+/, "_")
    end
  end
end
```

Использование:

```ruby
AiSearchable::Tag.build("species", "dog")
# => "ai_searchable:species:dog"

AiSearchable::Tag.parse("ai_searchable:species:dog")
# => { dimension: "species", value: "dog" }
```

---

## 4. Модуль чтения YAML конфига
### AiSearchable::Config

Файл: `app/lib/ai_searchable/config.rb`

```ruby
module AiSearchable
  class Config
    CONFIG_PATH = Rails.root.join("config/ai_searchable.yml")

    class << self
      def raw
        @raw ||= YAML.load_file(CONFIG_PATH).fetch("ai_searchable")
      end

      def dimensions
        raw.keys
      end

      def values_for(dimension)
        dim = raw[dimension.to_s]
        return [] unless dim
        Array(dim["values"]).map(&:to_s)
      end

      def allow_any?(dimension)
        dim = raw[dimension.to_s]
        dim && dim["allow_any"] == true
      end

      # Новый метод: единое место для LLM схемы
      #
      # Пример:
      # {
      #   species: { type: "enum", values: ["dog", "cat"] },
      #   brand:   { type: "string" }
      # }
      def to_llm_schema
        raw.each_with_object({}) do |(dimension, cfg), acc|
          if cfg["allow_any"]
            acc[dimension.to_sym] = {
              type: "string",
              multiple: false
            }
          else
            acc[dimension.to_sym] = {
              type: "enum",
              values: Array(cfg["values"]),
              multiple: true # по умолчанию для enum; можно расширить позже
            }
          end
        end
      end
    end
  end
end
```

Теперь LLM schema можно получать так:

```ruby
AiSearchable::Config.to_llm_schema
```

---

## 5. AiSearchableTag

Файл из v2 без изменений, только добавляем использование `AiSearchable::Tag.normalize_value` в нормализации.

```ruby
class AiSearchableTag
  include ActiveModel::Model

  AI_PREFIX = "ai_searchable".freeze

  attr_accessor :raw_name, :name, :dimension, :value

  validates :name, presence: true
  validate :validate_ai_format
  validate :validate_value

  def self.ai?(raw_name)
    raw_name.to_s.start_with?("#{AI_PREFIX}:")
  end

  def self.normalize(raw_name)
    return "" if raw_name.blank?
    raw_name.strip.downcase.gsub(/\s+/, "_")
  end

  def initialize(raw_name:)
    @raw_name = raw_name
    @name = self.class.normalize(raw_name)
    parse
  end

  private

  def parse
    parts = name.split(":")
    return unless parts.size == 3 && parts.first == AI_PREFIX
    @dimension = parts[1]
    @value = parts[2]
  end

  def validate_ai_format
    return unless self.class.ai?(raw_name)
    unless dimension && value
      errors.add(:base, "invalid ai_searchable format")
    end
  end

  def validate_value
    return unless dimension && value
    return if AiSearchable::Config.allow_any?(dimension)

    allowed = AiSearchable::Config.values_for(dimension)
    unless allowed.include?(value)
      errors.add(:base, "invalid value '#{value}' for dimension '#{dimension}'")
    end
  end
end
```

---

## 6. Декоратор ActsAsTaggableOn::Tag

Без изменений, добавили только normalize через helper:

```ruby
def normalize_ai_tag
  return if name.blank?

  if AiSearchableTag.ai?(name)
    self.name = AiSearchableTag.normalize(name)
  else
    self.name = name.strip.downcase.gsub(/\s+/, "_")
  end
end
```

---

## 7. ProductAttributes

Оставляем без изменений — структура ок.
Но теперь можем использовать `AiSearchable::Tag.parse` если захотим.

---

## 8. ProductSearch (с использованием Tag.build)

Вместо ручного `"ai_searchable:species:#{sp}"`:

```ruby
scope = scope.tagged_with(AiSearchable::Tag.build("species", sp), any: true)
```

Обновленный вариант:

```ruby
if @species
  @species.each do |sp|
    scope = scope.tagged_with(AiSearchable::Tag.build("species", sp), any: true)
  end
end

if @format
  scope = scope.tagged_with(AiSearchable::Tag.build("format", @format), any: true)
end

if @diet
  scope = scope.tagged_with(AiSearchable::Tag.build("diet", @diet), any: true)
end

if @problems
  @problems.each do |pb|
    scope = scope.tagged_with(AiSearchable::Tag.build("problem", pb), any: true)
  end
end

if @brand
  scope = scope.tagged_with(AiSearchable::Tag.build("brand", @brand), any: true)
end
```

---

## 9. Итог

**Что нового добавлено в v2.1:**

- Центральный helper `AiSearchable::Tag`
  - `build(dimension, value)`
  - `parse(tag_string)`
  - `normalize_value(value)`
- `AiSearchable::Config.to_llm_schema` для генерации схемы инструмента LLM
- Обновленные примеры в ProductSearch и Config

Это убирает дублирование строк, упрощает тестирование, а самое главное — делает LLM-tool всегда синхронизированным с YAML конфигом.
