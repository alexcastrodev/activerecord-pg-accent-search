require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'activerecord', '~> 8.1.1'
  gem 'pg', '~> 1.5'
  gem 'testcontainers-postgres', '~> 0.2.0'
  gem 'minitest', '~> 5.25'
end

require 'active_record'
require 'testcontainers/postgres'
require 'minitest/autorun'

POSTGRES_CONTAINER = Testcontainers::PostgresContainer.new("postgres:17")
POSTGRES_CONTAINER.start

ActiveRecord::Base.establish_connection(POSTGRES_CONTAINER.database_url)
ActiveRecord::Base.logger = nil

ActiveRecord::Schema.define do
  drop_table :products, if_exists: true

  create_table :products do |t|
    t.string :name, null: false
    t.timestamps
  end
end

class Product < ActiveRecord::Base
  scope :search_by_name, ->(term) {
    # Using only trim and lower
    where("lower(trim(name)) = lower(trim(?))", term)
  }
end

class SimpleLowerSearchTest < Minitest::Test
  def setup
    Product.delete_all
    Product.create!(name: 'José')
    Product.create!(name: 'Maçã de Arroz')
  end

  def test_does_not_find_jose_without_accent
    # 'jose' -> lower -> 'jose'
    # 'José' -> lower -> 'josé'
    # 'jose' != 'josé' => Should not match
    results = Product.search_by_name('jose')
    assert_equal 0, results.count
  end

  def test_finds_jose_with_accent
    results = Product.search_by_name('José')
    assert_equal 1, results.count
    assert_equal 'José', results.first.name
  end

  def test_finds_jose_with_mixed_case
    results = Product.search_by_name('josé')
    assert_equal 1, results.count
    assert_equal 'José', results.first.name
  end

  def test_finds_maca_de_arroz_with_mixed_case
    results = Product.search_by_name('maçã de arroz')
    assert_equal 1, results.count
    assert_equal 'Maçã de Arroz', results.first.name
  end
  
  # Edge case: Turkish I?
  # Postgres docker default locale is usually en_US.utf8 or C.UTF-8
end

Minitest.after_run do
  POSTGRES_CONTAINER.stop
  POSTGRES_CONTAINER.remove
end
