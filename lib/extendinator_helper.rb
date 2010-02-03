require 'verbosinator'

class ExtendinatorHelper

  constructor :rake_wrapper


  def instantiate_extender_script(extender, system_objects)
    return eval "#{extender}.new(system_objects)"
  end


  def rake_task_invoked?(task_regex)
    task_invoked = false
    @rake_wrapper.task_list.each do |task|
      if ((task.already_invoked) and (task.to_s =~ task_regex))
        task_invoked = true
        break
      end
    end
    return task_invoked
  end

end
