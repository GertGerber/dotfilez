packer {
  required_plugins { null = { version = ">= 1.0.0", source = "github.com/hashicorp/null" } }
}
source "null" "example" {}
build {
  name    = "base-image"
  sources = ["source.null.example"]
}
