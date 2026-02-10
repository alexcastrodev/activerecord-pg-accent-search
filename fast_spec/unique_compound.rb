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
  drop_table :data_sources, if_exists: true

  create_table :data_sources do |t|
    t.integer :data_source_id, null: false
    t.string :scope, null: false
    t.string :data_origin, null: false
    t.timestamps
  end

  add_index :data_sources, [:scope, :data_origin, :data_source_id], unique: true, name: 'idx_unique_scope_origin_source'
end

class DataSource < ActiveRecord::Base
  validates :data_source_id, uniqueness: { scope: [:scope, :data_origin] }
end

class UniqueCompoundTest < Minitest::Test
  def setup
    DataSource.delete_all
  end

  def test_same_data_source_id_for_two_different_tenants
    DataSource.create!(data_source_id: 1, scope: 'tenant_a', data_origin: 'api')
    record = DataSource.create!(data_source_id: 1, scope: 'tenant_b', data_origin: 'api')

    assert_equal 2, DataSource.where(data_source_id: 1).count
  end

  def test_duplicate_data_source_id_for_same_tenant
    DataSource.create!(data_source_id: 1, scope: 'tenant_a', data_origin: 'api')
    record = DataSource.new(data_source_id: 1, scope: 'tenant_a', data_origin: 'api')

    refute record.valid?
    assert_includes record.errors[:data_source_id], 'has already been taken'
  end
end

Minitest.after_run do
  POSTGRES_CONTAINER.stop
  POSTGRES_CONTAINER.remove
end
