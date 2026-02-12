variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
}

variable "tags" {
  description = "Tags AWS à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
