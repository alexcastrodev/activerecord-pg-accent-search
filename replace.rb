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

POSTGRES_CONTAINER = Testcontainers::PostgresContainer.new("postgres:18")
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

ACCENT_MAP = {
  'À' => 'A', 'Á' => 'A', 'Â' => 'A', 'Ã' => 'A', 'Ä' => 'A', 'Å' => 'A',
  'à' => 'a', 'á' => 'a', 'â' => 'a', 'ã' => 'a', 'ä' => 'a', 'å' => 'a',
  'È' => 'E', 'É' => 'E', 'Ê' => 'E', 'Ë' => 'E',
  'è' => 'e', 'é' => 'e', 'ê' => 'e', 'ë' => 'e',
  'Ì' => 'I', 'Í' => 'I', 'Î' => 'I', 'Ï' => 'I',
  'ì' => 'i', 'í' => 'i', 'î' => 'i', 'ï' => 'i',
  'Ò' => 'O', 'Ó' => 'O', 'Ô' => 'O', 'Õ' => 'O', 'Ö' => 'O',
  'ò' => 'o', 'ó' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o',
  'Ù' => 'U', 'Ú' => 'U', 'Û' => 'U', 'Ü' => 'U',
  'ù' => 'u', 'ú' => 'u', 'û' => 'u', 'ü' => 'u',
  'Ç' => 'C', 'ç' => 'c',
  'Ñ' => 'N', 'ñ' => 'n',
  'Ý' => 'Y', 'ý' => 'y'
}

def self.strip_accents_sql(column)
  ACCENT_MAP.reduce("lower(#{column})") do |sql, (accented, plain)|
    "replace(#{sql}, '#{accented}', '#{plain}')"
  end
end

STRIP_ACCENTS_EXPR = strip_accents_sql('name')

class Product < ActiveRecord::Base
  scope :search_by_name, ->(term) {
    term_expr = strip_accents_sql('?')
    where("#{STRIP_ACCENTS_EXPR} = #{term_expr}", term)
  }
end

class ReplaceSearchTest < Minitest::Test
  def setup
    Product.delete_all
    Product.create!(name: 'José')
    Product.create!(name: 'Maçã de Arroz')
  end

  def test_finds_jose_without_accent
    results = Product.search_by_name('jose')

    assert_equal 1, results.count
    assert_equal 'José', results.first.name
  end

  def test_finds_jose_with_accent
    results = Product.search_by_name('José')

    assert_equal 1, results.count
    assert_equal 'José', results.first.name
  end

  def test_finds_maca_de_arroz_without_accents
    results = Product.search_by_name('maca de arroz')

    assert_equal 1, results.count
    assert_equal 'Maçã de Arroz', results.first.name
  end

  def test_finds_maca_de_arroz_with_accents
    results = Product.search_by_name('Maçã de Arroz')

    assert_equal 1, results.count
    assert_equal 'Maçã de Arroz', results.first.name
  end
end

Minitest.after_run do
  POSTGRES_CONTAINER.stop
  POSTGRES_CONTAINER.remove
end
