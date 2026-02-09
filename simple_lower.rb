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
    Product.create!(name: 'ºC')
    Product.create!(name: 'm3/d')
    Product.create!(name: 'm²')
    Product.create!(name: 'kg/cm²')
    Product.create!(name: 'Wh/(m³•mca)')
    Product.create!(name: 'm³/día')
    Product.create!(name: 'Tan φ')
    Product.create!(name: 'Cos φ')
    Product.create!(name: '%')
    Product.create!(name: 'µS/cm')
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

  def test_finds_graus_celsius
    # 'ºC' -> lower -> 'ºc'
    results = Product.search_by_name('ºC')
    assert_equal 1, results.count
    assert_equal 'ºC', results.first.name
  end
  
  def test_finds_m3_d
    # 'm3/d' -> lower -> 'm3/d'
    results = Product.search_by_name('m3/d')
    assert_equal 1, results.count
    assert_equal 'm3/d', results.first.name
  end
  
  def test_finds_m3_d_different_case
    # o contrario da db
    results = Product.search_by_name('M3/D')
    assert_equal 1, results.count
    assert_equal 'm3/d', results.first.name
  end
  
  def test_finds_celsius_with_different_case
    # o contrario da db
    results = Product.search_by_name('ºc')
    assert_equal 1, results.count
    assert_equal 'ºC', results.first.name
  end

  # Agora uns doido
  def test_finds_m2
    results = Product.search_by_name('m²')
    assert_equal 1, results.count
    assert_equal 'm²', results.first.name
  end

  def test_finds_kg_cm2
    results = Product.search_by_name('kg/cm²')
    assert_equal 1, results.count
    assert_equal 'kg/cm²', results.first.name
  end

  def test_finds_wh_m3_mca
    results = Product.search_by_name('Wh/(m³•mca)')
    assert_equal 1, results.count
    assert_equal 'Wh/(m³•mca)', results.first.name
  end

  def test_finds_m3_dia
    results = Product.search_by_name('m³/día')
    assert_equal 1, results.count
    assert_equal 'm³/día', results.first.name
  end

  def test_finds_tan_phi
    results = Product.search_by_name('TAN φ')
    assert_equal 1, results.count
    assert_equal 'Tan φ', results.first.name
  end

  def test_finds_cos_phi
    results = Product.search_by_name('cos φ')
    assert_equal 1, results.count
    assert_equal 'Cos φ', results.first.name
  end

  def test_finds_percent
    results = Product.search_by_name('%')
    assert_equal 1, results.count
    assert_equal '%', results.first.name
  end

  def test_finds_micro_s_cm
    results = Product.search_by_name('µS/cm')
    assert_equal 1, results.count
    assert_equal 'µS/cm', results.first.name
  end
end

Minitest.after_run do
  POSTGRES_CONTAINER.stop
  POSTGRES_CONTAINER.remove
end
