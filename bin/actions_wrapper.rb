require 'thor'

# Wrapper for handy Thor Actions
class ActionsWrapper
  include Thor::Base
  include Thor::Actions

  source_root( CEEDLING_ROOT )

  def _directory( src, dest )
    directory( src, dest )
  end

  def _copy_file( src, dest )
    copy_file( src, dest )
  end

end
