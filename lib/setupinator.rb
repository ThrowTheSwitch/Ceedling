
class Setupinator

  constructor :project_file_loader, :configurator, :test_includes_extractor

  def setupinate
    # load project yaml file
    @project_file_loader.find_project_file
    config_hash = @project_file_loader.load_project

    # load up all the constants and accessors our rake files, objects, & external scripts will need;
    # note: configurator modifies the cmock section of the hash with a couple defaults to tie 
    #       project together - the modified hash is used to build cmock object
    @configurator.standardize_paths(config_hash)
    @configurator.validate(config_hash)
    @configurator.insert_cmock_defaults(config_hash)
    @configurator.build(config_hash)
    
    # a bit unorthodox to insert these values here, but it simplifies the code quite a bit;
    # and we have to wait until the configurator is done with setup before we can get at them
    @test_includes_extractor.cmock_mock_prefix = @configurator.cmock_mock_prefix
    @test_includes_extractor.extension_header  = @configurator.extension_header
  end

end
