#!/bin/bash

# Read the list of paths to the GCR repositories from the file
repositories=$(cat "$PATH_OF_LIST")

# Loop through the list of repositories
for repository in $repositories; do

  # Get the list of images in the repository
  images=$(gcloud container images list-tags "$repository" --limit=999999 --sort-by=TIMESTAMP)

  # Check if images variable is empty
  if [ -z "$images" ]; then
    echo "Error: Failed to retrieve images for repository $repository"
    echo "--------------------------"
    continue
  fi

  # Count the number of images in the repository
  num_images=$(echo "$images" | wc -l)

  # Get the list of images that are 30 days old
  old_images=$(gcloud container images list-tags "$repository" --limit=999999 --sort-by=TIMESTAMP --filter='timestamp.datetime < "-P30D"')

  # Check if old_images variable is empty
  if [ -z "$old_images" ]; then
    echo "No old images found in this repository."
    echo "--------------------------"
    continue
  fi

  num_old_images=$(echo "$old_images" | wc -l)

  # Keep the latest 5 images
  latest_images=$(echo "$images" | tail -n 5)

  # Print the repository name and number of images
  echo "Repository: $repository"
  echo "--------------------------"

  echo "Number of Images: $num_images"
  echo "--------------------------"
  echo "Number of Images that are 30 days old: $num_old_images"
  echo "--------------------------"
  echo "Latest 5 Images:"
  echo "$latest_images"
  echo "--------------------------"

  # Delete the images that are 30 days old, excluding the latest 5 images
  while IFS= read -r image_digest; do
    echo "Deleting: $repository@$image_digest"
    if ! echo "$latest_images" | grep -q "$image_digest"; then
      echo $image_digest
      gcloud container images delete "${repository}@sha256:${image_digest}" --force-delete-tags --quiet
    fi
  done <<< "$(tail -n +2 <<< "$old_images" | awk '{print $1}')"

  echo "--------------------------"

  # Get the updated list of images after deletion
  updated_images=$(gcloud container images list-tags "$repository" --limit=999999 --sort-by=TIMESTAMP)
  updated_num_images=$(echo "$updated_images" | wc -l)

  # Print the total number of images in green color
  echo -e "Total Number of Images: \e[32m$updated_num_images\e[0m"
  echo "--------------------------"
done
