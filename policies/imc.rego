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
satisfies_image_architecture(reqimage, image){
  reqimage.architecture = image.architecture
}

satisfies_image_architecture(reqimage, image){
  not reqimage.architecture
}

satisfies_image_distribution(reqimage, image){
  reqimage.distribution = image.distribution
}

satisfies_image_distribution(reqimage, image){
  not reqimage.distribution
}

satisfies_image_type(reqimage, image){
  reqimage.type = image.type
}

satisfies_image_type(reqimage, image){
  not reqimage.type
}

satisfies_image_version(reqimage, image){
  reqimage.version = image.version
}

satisfies_image_version(reqimage, image){
  not reqimage.version
}

satisfies_image_name(reqimage, image){
  reqimage.name = image.name
}

satisfies_image_name(reqimage, image){
  not reqimage.name
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
  myimage = clouds[site]["images"][i]
  myflavour = clouds[site]["flavours"][j]
  satisfies_region(input.requirements, cloud)
  satisfies_site(input.requirements, cloud)
  satisfies_image(input.requirements, myimage)
  satisfies_flavour(input.requirements, myflavour)
  satisfies_quotas(input.requirements, cloud)
}

# Get images for a specified cloud
images[name] {
  myimage = clouds[input.cloud]["images"][image]
  name = myimage.name
  satisfies_image(input.requirements, myimage)
}

# Rank flavours for a specified cloud
flavours[pair] {
  myflavour =  clouds[input.cloud]["flavours"][flavour]
  satisfies_flavour(input.requirements, myflavour)
  weight = flavour_weight(myflavour)
  pair = {"name":flavour, "weight":weight}
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
