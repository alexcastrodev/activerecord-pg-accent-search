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
  ACCENT_MAP = {
    'Á' => 'á', 'À' => 'à', 'Â' => 'â', 'Ã' => 'ã', 'Ä' => 'ä', 'Å' => 'å',
    'É' => 'é', 'È' => 'è', 'Ê' => 'ê', 'Ë' => 'ë',
    'Í' => 'í', 'Ì' => 'ì', 'Î' => 'î', 'Ï' => 'ï',
    'Ó' => 'ó', 'Ò' => 'ò', 'Ô' => 'ô', 'Õ' => 'õ', 'Ö' => 'ö',
    'Ú' => 'ú', 'Ù' => 'ù', 'Û' => 'û', 'Ü' => 'ü',
    'Ç' => 'ç', 'Ñ' => 'ñ', 'Ý' => 'ý'
  }

  def self.lowercase_sensitive_sql(column)
    ACCENT_MAP.reduce("lower(#{column})") do |sql, (upper, lower)|
      "replace(#{sql}, '#{upper}', '#{lower}')"
    end
  end

  LOWERCASE_EXPR = lowercase_sensitive_sql('name')

  scope :search_by_name, ->(term) {
    term_expr = lowercase_sensitive_sql('?')
    where("#{LOWERCASE_EXPR} = #{term_expr}", term)
  }
end

class ReplaceSearchTest < Minitest::Test
  def setup
    Product.delete_all
    Product.create!(name: 'José')
    Product.create!(name: 'Maçã de Arroz')
  end

  def test_does_not_find_jose_without_accent
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

  def test_does_not_find_maca_de_arroz_without_accents
    results = Product.search_by_name('maca de arroz')
    assert_equal 0, results.count
  end

  def test_finds_maca_de_arroz_with_accents
    results = Product.search_by_name('Maçã de Arroz')
    assert_equal 1, results.count
    assert_equal 'Maçã de Arroz', results.first.name
  end

  def test_finds_maca_de_arroz_with_mixed_case
    results = Product.search_by_name('maçã de arroz')
    assert_equal 1, results.count
    assert_equal 'Maçã de Arroz', results.first.name
  end
end

Minitest.after_run do
  POSTGRES_CONTAINER.stop
  POSTGRES_CONTAINER.remove
end
