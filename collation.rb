# encoding: utf-8
# frozen_string_literal: true

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

ActiveRecord::Base.connection.execute(<<~SQL)
  DO $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_collation WHERE collname = 'accent_insensitive') THEN
      CREATE COLLATION accent_insensitive (
        provider = icu,
        locale = 'und-u-ks-level1',
        deterministic = false
      );
    END IF;
  END $$;
SQL

ActiveRecord::Schema.define do
  drop_table :products, if_exists: true

  create_table :products do |t|
    t.string :name, null: false
    t.timestamps
  end
end

class Product < ActiveRecord::Base
  scope :search_by_name, ->(term) {
    where("name COLLATE \"accent_insensitive\" = ? COLLATE \"accent_insensitive\"", term)
  }
end

class CollationSearchTest < Minitest::Test
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
