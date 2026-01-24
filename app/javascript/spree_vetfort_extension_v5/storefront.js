import { application } from "controllers/application"
import TestController from "spree_vetfort_extension_v5/controllers/test_controller"

export function boot() {
  application.register("test", TestController)
}


