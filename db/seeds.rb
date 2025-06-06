# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Vote.destroy_all
User.destroy_all

User.create!(username: "Deezer", email: "deezer@system.com", password: "azerty")
User.create!(username: "NathanLBM", email: "nathan@dropone.fr", password: "azerty")
User.create!(username: "Vyddou", email: "ugo@dropone.fr", password: "azerty")
User.create!(username: "Flaflamobile", email: "fred@dropone.fr", password: "azerty")
User.create!(username: "Roroapero", email: "romain@dropone.fr", password: "azerty")
User.create!(username: "Wulfens", email: "mathieu@dropone.fr", password: "azerty")
