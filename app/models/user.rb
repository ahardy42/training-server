class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable, :validatable

  has_many :activities, dependent: :destroy

  enum :units, { metric: "metric", imperial: "imperial" }

  validates :height, numericality: { greater_than: 0, allow_nil: true }
  validates :weight, numericality: { greater_than: 0, allow_nil: true }
  validates :date_of_birth, presence: false
  validates :ftp, numericality: { greater_than: 0, allow_nil: true, only_integer: true }
  validates :lt_hr, numericality: { greater_than: 0, allow_nil: true, only_integer: true }
  validates :max_hr, numericality: { greater_than: 0, allow_nil: true, only_integer: true }
end
