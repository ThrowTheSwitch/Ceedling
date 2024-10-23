if $_isvoid ($_exitcode)
  call ((void(*)(int))fflush)(0)
  backtrace
  kill
end
