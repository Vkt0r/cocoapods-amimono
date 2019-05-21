require 'cocoapods/installer'
require 'cocoapods-amimono/xcconfig_updater'
require 'cocoapods-amimono/xcconfig_helper'

module Amimono
  # This class will patch your project's copy resources script to match the one that would be
  # generated as if the `use_frameworks!` flag wouldn't be there
  class Patcher

    def self.patch!(installer)
      patch_xcconfig_files(installer)
      patch_copy_resources_script(installer)
      patch_vendored_build_settings(installer)
      patch_embed_frameworks_script(installer)
    end

    private

    def self.patch_xcconfig_files(installer)
      aggregated_targets = installer.aggregate_targets
      updater = XCConfigUpdater.new(installer)
      aggregated_targets.each do |aggregated_target|
        puts "[Amimono] Pods target found: #{aggregated_target.label}"
        target_support = installer.sandbox.target_support_files_dir(aggregated_target.label)
        updater.update_xcconfigs(aggregated_target, target_support)
        puts "[Amimono] xcconfigs updated with filelist for target #{aggregated_target.label}"
      end
    end

    def self.patch_vendored_build_settings(installer)
      aggregated_targets = installer.aggregate_targets
      aggregated_targets.each do |aggregated_target|
        path = installer.sandbox.target_support_files_dir aggregated_target.label
        Dir.entries(path).select { |entry| entry.end_with? 'xcconfig' }.each do |entry|
          full_path = path + entry
          xcconfig = Xcodeproj::Config.new full_path
          # Another option would be to inspect installer.analysis_result.result.target_inspections
          # But this also works and it's simpler
          configuration = entry.split('.')[-2]
          pod_targets = aggregated_target.pod_targets_for_build_configuration configuration
          generate_vendored_build_settings(aggregated_target, pod_targets, xcconfig)
          xcconfig.save_as full_path
        end
        puts "[Amimono] Vendored build settings patched for target #{aggregated_target.label}"
      end
    end

    def self.generate_vendored_build_settings(aggregated_target, pod_targets, xcconfig)
      targets = pod_targets + aggregated_target.search_paths_aggregate_targets.flat_map(&:pod_targets)

      targets.each do |pod_target|
        XCConfigHelper.add_settings_for_file_accessors_of_target(aggregated_target, pod_target, xcconfig)
      end
  end

    def self.patch_copy_resources_script(installer)
      project = installer.sandbox.project
      aggregated_targets = installer.aggregate_targets
      aggregated_targets.each do |aggregated_target|
        path = aggregated_target.copy_resources_script_path
        resources = aggregated_target.resource_paths_by_config
        generator = Pod::Generator::CopyResourcesScript.new(resources, aggregated_target.platform)
        generator.save_as(path)
        puts "[Amimono] Copy resources script patched for target #{aggregated_target.label}"
      end
    end

    def self.patch_embed_frameworks_script(installer)
      project = installer.sandbox.project
      aggregated_targets = installer.aggregate_targets
      aggregated_targets.each do |aggregated_target|
        path = aggregated_target.embed_frameworks_script_path
        frameworks = aggregated_target.framework_paths_by_config
        generator = Pod::Generator::EmbedFrameworksScript.new(frameworks)
        generator.save_as(path)
        puts "[Amimono] Embed frameworks script patched for target #{aggregated_target.label}"
      end
    end
  end
end
