#doc: REGEX_REMOVE_ITEM("${TESTLIST}" ".wo" result_list)
#     remove any item that matches the regex .wo from TESTLIST
#     save the result in result_list
function(REGEX_REMOVE_ITEM VALUES REGEX_STR OUTPUT)
  
  foreach(_ITEM IN LISTS VALUES)
    string(REGEX MATCH "${REGEX_STR}" _MATCHRESULT ${_ITEM})

    if(${_MATCHRESULT} MATCHES ${REGEX_STR})
      list(REMOVE_ITEM VALUES ${_ITEM})
      break()
    endif()
    unset(_MATCHRESULT)
  endforeach()

  set(${OUTPUT} ${VALUES} PARENT_SCOPE)
endfunction()

#doc: PREPEND_ITEM("${TESTLIST}" "42" result_list)
#     prepend "42" to every item in TESTLIST 
#     save the result in result_list
function(PREPEND_ITEM VALUES PREPEND_STR OUTPUT)

  set(${_OUTPUT} "")
  
  foreach(_ITEM IN LISTS VALUES)
    list(APPEND _OUTPUT "${PREPEND_STR}${_ITEM}")
  endforeach()
  
  set(${OUTPUT} ${_OUTPUT} PARENT_SCOPE)
endfunction()
