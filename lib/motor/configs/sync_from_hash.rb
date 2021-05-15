# frozen_string_literal: true

module Motor
  module Configs
    module SyncFromHash
      module_function

      def call(configs_hash)
        configs_hash = configs_hash.with_indifferent_access

        Motor::ApplicationRecord.transaction do
          sync_queries(configs_hash)
          sync_alerts(configs_hash)
          sync_dashboards(configs_hash)
          sync_forms(configs_hash)
          sync_configs(configs_hash)
          sync_resources(configs_hash)
        end
      end

      def sync_queries(configs_hash)
        sync_taggable(
          Motor::Configs::LoadFromCache.load_queries,
          configs_hash[:queries],
          configs_hash[:file_version],
          Motor::Queries::Persistance.method(:update_from_params!)
        )
      end

      def sync_alerts(configs_hash)
        sync_taggable(
          Motor::Configs::LoadFromCache.load_alerts,
          configs_hash[:alerts],
          configs_hash[:file_version],
          Motor::Alerts::Persistance.method(:update_from_params!)
        )
      end

      def sync_forms(configs_hash)
        sync_taggable(
          Motor::Configs::LoadFromCache.load_forms,
          configs_hash[:forms],
          configs_hash[:file_version],
          Motor::Forms::Persistance.method(:update_from_params!)
        )
      end

      def sync_dashboards(configs_hash)
        sync_taggable(
          Motor::Configs::LoadFromCache.load_dashboards,
          configs_hash[:dashboards],
          configs_hash[:file_version],
          Motor::Dashboards::Persistance.method(:update_from_params!)
        )
      end

      def sync_configs(configs_hash)
        configs_index = Motor::Configs::LoadFromCache.load_configs.index_by(&:key)

        configs_hash[:configs].each do |attrs|
          record = configs_index[attrs[:key]] || Motor::Config.new

          next if record.updated_at && attrs[:updated_at] <= record.updated_at

          record.update!(attrs)
        end
      end

      def sync_resources(configs_hash)
        resources_index = Motor::Configs::LoadFromCache.load_resources.index_by(&:name)

        configs_hash[:resources].each do |attrs|
          record = resources_index[attrs[:name]] || Motor::Resource.new

          next if record.updated_at && attrs[:updated_at] <= record.updated_at

          record.update!(attrs)
        end
      end

      def sync_taggable(records, config_items, configs_timestamp, update_proc)
        processed_records, create_items = update_taggable_items(records, config_items, update_proc)

        create_taggable_items(create_items, records.klass, update_proc)

        archive_taggable_items(records - processed_records, configs_timestamp)

        ActiveRecord::Base.connection.reset_pk_sequence!(records.klass.table_name)
      end

      def update_taggable_items(records, config_items, update_proc)
        record_ids_hash = records.index_by(&:id)

        config_items.each_with_object([[], []]) do |attrs, (processed_acc, create_acc)|
          record = record_ids_hash[attrs[:id]]

          next create_acc << attrs unless record

          processed_acc << record if record

          next if record.updated_at >= attrs[:updated_at]

          update_proc.call(record, attrs, force_replace: true)
        end
      end

      def create_taggable_items(create_items, records_class, update_proc)
        create_items.each do |attrs|
          record = records_class.find_or_initialize_by(id: attrs[:id]).tap { |e| e.deleted_at = nil }

          update_proc.call(record, attrs, force_replace: true)
        end
      end

      def archive_taggable_items(records_to_remove, configs_timestamp)
        records_to_remove.each do |record|
          next if record.updated_at > configs_timestamp

          record.update!(deleted_at: Time.current) if record.deleted_at.blank?
        end
      end
    end
  end
end
