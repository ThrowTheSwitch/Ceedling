
class Setupinator

  constructor :project_file_loader, :configurator, :test_includes_extractor, :extendinator

  def do_setup(system_objects)
    # load project yaml file
    @project_file_loader.find_project_files
    config_hash = @project_file_loader.load_project_file

    # load up all the constants and accessors our rake files, objects, & external scripts will need;
    # note: configurator modifies the cmock section of the hash with a couple defaults to tie 
    #       project together - the modified hash is used to build cmock object
    @configurator.populate_extenders_defaults(config_hash)
    @configurator.standardize_paths(config_hash)
    @configurator.validate(config_hash)
    @configurator.build_cmock_defaults(config_hash)
    @configurator.find_and_merge_extenders(config_hash)
    @configurator.build(config_hash)
    @configurator.insert_rake_extenders(@configurator.rake_extenders)

    @extendinator.load_extender_scripts(@configurator.script_extenders, system_objects)

    # a bit unorthodox to insert these values here, but it simplifies the code quite a bit;
    # and we have to wait until the configurator is done with setup before we can get at them
    @test_includes_extractor.cmock_mock_prefix = @configurator.cmock_mock_prefix
    @test_includes_extractor.extension_header  = @configurator.extension_header
  end

end
