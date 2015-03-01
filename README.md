erl_chatserver
==============

A simple erlang chatserver with a small easter egg that if you enter /{POKEMON_NAME}, the server will broadcast the description of the Pokemon to all those who are connected to the server at that point.

Instructions
------------
NOTE: You need to have Erlang(R13+) installed on your machine. Debian users can simply  do ```sudo apt-get install erlang``` to install it.


1. ```erl -make```
2. ```erl -pa ebin```
3. ```erl_chatserver:start(6667)````

Now simply have any client(s) connect to 6667 and start sending messages!

Dependencies
-------------

1. [jsx](https://github.com/talentdeficit/jsx) copyright 2010-2014 alisdair sullivan

