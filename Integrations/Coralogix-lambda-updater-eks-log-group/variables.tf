variable "existing_lambda_to_coralogix_name" {
  type = string
  validation {
    condition     = length(var.existing_lambda_to_coralogix_name) > 0
    error_message = "The lambda name that sends to Coralogix cannot be empty"
  }
}
variable "eks_new_function_name" {
  type = string
}