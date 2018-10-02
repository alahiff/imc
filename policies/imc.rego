package imc

import data.clouds
import data.status

# Regions
satisfies_region(requirements, cloud) {
  not requirements.regions
}

satisfies_region(requirements, cloud) {
  requirements.regions[i] = cloud.region
}

# Sites
satisfies_site(requirements, cloud) {
  not requirements.sites
}

satisfies_site(requirements, cloud) {
  requirements.sites[i] = cloud.name
}

# Images
satisfies_image_architecture(image_req, image){
  image_req.architecture = image.architecture
}

satisfies_image_architecture(image_req, image){
  not image_req.architecture
}

satisfies_image_distribution(image_req, image){
  image_req.distribution = image.distribution
}

satisfies_image_distribution(image_req, image){
  not image_req.distribution
}

satisfies_image_type(image_req, image){
  image_req.type = image.type
}

satisfies_image_type(image_req, image){
  not image_req.type
}

satisfies_image_version(image_req, image){
  image_req.version = image.version
}

satisfies_image_version(image_req, image){
  not image_req.version
}

satisfies_image_name(image_req, image){
  image_req.name = image.name
}

satisfies_image_name(image_req, image){
  not image_req.name
}

satisfies_image(requirements, image) {
  not requirements.image
}

satisfies_image(requirements, image) {
  satisfies_image_architecture(requirements.image, image)
  satisfies_image_distribution(requirements.image, image)
  satisfies_image_type(requirements.image, image)
  satisfies_image_version(requirements.image, image)
  satisfies_image_name(requirements.image, image)
}

# Flavours
satisfies_flavour(requirements, flavour) {
  flavour.cores >= requirements.resources.cores
  flavour.memory >= requirements.resources.memory
}

satisfies_flavour(requirements, flavour) {
  not requirements.resources.cores
  not requirements.resources.memory
}

# Quotas
satisfies_quotas(requirements, cloud) {
  requirements.resources.cores * requirements.resources.instances <= cloud.quotas.cores
  requirements.resources.instances <= cloud.quotas.instances
}

satisfies_quotas(requirements, cloud) {
  requirements.resources.cores * requirements.resources.instances <= cloud.quotas.cores
  not cloud.quotas.instances
}

satisfies_quotas(requirements, cloud) {
  not cloud.quotas
}

# Get list of sites meeting requirements
sites[site] {
  cloud = clouds[site]
  image = clouds[site]["images"][i]
  flavour = clouds[site]["flavours"][j]
  satisfies_region(input.requirements, cloud)
  satisfies_site(input.requirements, cloud)
  satisfies_image(input.requirements, image)
  satisfies_flavour(input.requirements, flavour)
  satisfies_quotas(input.requirements, cloud)
}

# Get images for a specified cloud
images[name] {
  image = clouds[input.cloud]["images"][i]
  name = image.name
  satisfies_image(input.requirements, image)
}

# Rank flavours for a specified cloud
flavours[pair] {
  flavour =  clouds[input.cloud]["flavours"][i]
  satisfies_flavour(input.requirements, flavour)
  weight = flavour_weight(flavour)
  pair = {"name":flavour.name, "weight":weight}
}

# Rank sites based on preferences
rankedsites[pair] {
  weight = region_weight(site) - recent_failures(site) * 1000
  site = input.clouds[i]
  pair = {"site":site, "weight":weight}
}

# Current time in seconds
timenow_secs() = output {
  time.now_ns(ns_output)
  output = ns_output * 1e-9
}

# Check for recent failures
recent_failures(site) = output {
  timenow_secs - status[site][i]["epoch"] < 3600
  output = 1
}

recent_failures(site) = output {
  not status[site]
  output = 0
}

# Region weight
region_weight(site) = output {
  cloud = clouds[site]
  i = cloud.region
  output = input.preferences.regions[i]
}

region_weight(site) = output {
  cloud = clouds[site]
  i = cloud.region
  not input.preferences.regions[i]
  output = 0
}

# Flavour weight
flavour_weight(flavour) = output {
  output = flavour.cost
}

flavour_weight(flavour) = output {
  not flavour.cost
  product({flavour.cores, flavour.memory}, output)
}
