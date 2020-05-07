# Contact-Tracing
Erlang Dummy implementation of a contact tracing system for Emerging Programming Paradigms Course 2019-2020


# Utils

* global:registered_names(). --> return a list with all global registered names
* global:send(hospital, {test_me, self()}). --> send a message to global registered name
* cover:compile_directory().