# app/helpers/application_helper.rb
module ApplicationHelper
  def meta_title
    content_for(:title) || "DropOne - Partagez et découvrez la musique du moment"
  end

  def meta_description
    content_for(:description) || "DropOne est le réseau social pour les passionnés de musique. Partagez votre son du jour, votez pour les meilleures découvertes et créez des playlists uniques."
  end

  def meta_image
    # og_image.png' dans app/assets/images/
    # et qu'elle fait 1200x630 pixels.
    meta_image = content_for(:meta_image) || image_url("og_image.png")
    meta_image.starts_with?("http") ? meta_image : image_url(meta_image)
  end
end
