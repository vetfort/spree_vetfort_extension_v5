import { Application } from "@hotwired/stimulus";
import ProductImportController from "./controllers/product_import_controller";

const application = Application.start();
application.register("product-import", ProductImportController);
