class Follow < ApplicationRecord
  belongs_to :first_user
  belongs_to :second_user
end
