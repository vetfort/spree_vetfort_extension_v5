this extension includes patches for

## app/views/spree/admin/dashboard/_visits.html.erb
fixed `<%= flag_emoji(Country.find_by_name(location.first)&.first) %>`

method find_by_name [was removed](https://github.com/countries/countries/blob/6a786cfa2b75eae14d774d1eeba4d31021dc8e3a/README.md#attribute-based-finder-methods)

## added links page
`app/controllers/spree/spree_vetfort_extension_v5/links_controller.rb`

## also includes
- tailwind
- mjml
- ahoy_matey
- geocoder
- dry gems
- view_component

## Stimulus (Spree Admin, via extension)

This extension registers Stimulus controllers into the Spree Admin engine using a head partial.

- Engine hook: `lib/spree_vetfort_extension_v5/engine.rb` appends `spree/admin/shared/vetfort_extension_v5_head` to `Rails.application.config.spree_admin.head_partials`.
- Partial: `app/views/spree/admin/shared/_vetfort_extension_v5_head.html.erb` imports controllers and registers them on `window.Stimulus`.
- Controllers live under `app/assets/javascripts/spree/admin/spree_vetfort_extension_v5/` and are ES modules.

Head partial contents (simplified):

```erb
<script type="module">
  import ProductImportController from "/assets/spree/admin/spree_vetfort_extension_v5/product_import_controller.js";
  import ProductImportRowController from "/assets/spree/admin/spree_vetfort_extension_v5/product_import_row_controller.js";
  import VetfortNotificationController from "/assets/spree/admin/spree_vetfort_extension_v5/vetfort_notification_controller.js";
  import AiDescriptionController from "/assets/spree/admin/spree_vetfort_extension_v5/ai_description_controller.js";

  window.Stimulus.register("product-import", ProductImportController);
  window.Stimulus.register("product-import-row", ProductImportRowController);
  window.Stimulus.register("vetfort-notification", VetfortNotificationController);
  window.Stimulus.register("ai-description", AiDescriptionController);
</script>
```

Usage in admin views:

```erb
<div data-controller="product-import" data-product-import-path-value="/admin/product_imports/1"> ... </div>
```

Notes:
- Admin uses its own Stimulus app; registering on `window.Stimulus` ensures controllers are available without touching the core admin JS.
- When adding new controllers, place them in the same directory and import/register them in the head partial.

## Using npm/ESM packages in Stimulus controllers (Admin)

Add third‑party JS without a bundler by importing ESM builds in the admin head partial and exposing them via a single global registry.

1) Import the package and pin the version in `app/views/spree/admin/shared/_vetfort_extension_v5_head.html.erb`:

```erb
<script type="module">
  import PubSub from "https://esm.sh/pubsub-js@1.9.4";

  window.VetfortDeps ||= {};
  window.VetfortDeps.PubSub = PubSub;
</script>
```

2) Use the dependency inside a Stimulus controller under `app/assets/javascripts/spree/admin/spree_vetfort_extension_v5/`:

```js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const { PubSub } = window.VetfortDeps || {};
    if (!PubSub) { console.warn("PubSub not loaded"); return; }

    // Example usage
    PubSub.publish("descriptionGenerated", { ok: true });
  }
}
```

3) If needed, add more packages by importing them in the same head partial and assigning to `window.VetfortDeps` (e.g., `window.VetfortDeps.Dayjs = dayjs`). Always pin versions in the CDN URL to avoid unexpected upgrades.

Why this approach: keeps admin JS decoupled from Spree core, avoids adding a bundler, and provides a single place (`window.VetfortDeps`) to manage and update dependencies used by controllers.
