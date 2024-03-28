require 'thor'

# Wrapper for handy Thor Actions
class ActionsWrapper
  include Thor::Base
  include Thor::Actions

  source_root( CEEDLING_ROOT )

  def _directory( src, *args )
    directory( src, *args )
  end

  def _copy_file( src, *args )
    copy_file( src, *args )
  end

end
