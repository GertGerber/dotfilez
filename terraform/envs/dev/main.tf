terraform {
  required_version = ">= 1.5.0"
  required_providers { random = { source = "hashicorp/random" } }
}
provider "random" {}
resource "random_pet" "example" { length = 2 }
output "example" { value = random_pet.example.id }
