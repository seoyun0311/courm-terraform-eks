variable "repository_names" {
  description = "생성할 ECR 레포지토리 이름 목록 (다이어그램 기반)"
  type        = list(string)
  default     = [
    "goorm-cart",
    "goorm-product",
    "goorm-payment",
    "goorm-user",
    "goorm-order"
  ]
}
