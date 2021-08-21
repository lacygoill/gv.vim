Rewrite of [gv.vim](https://github.com/junegunn/gv.vim) in Vim9 script.

[gv.vim commit](https://github.com/junegunn/gv.vim/commit/5f902f4f7d06ef084ffd6cddcd1ee7d3c9a793c6)

Tested on Vim 8.2.3365 (Linux). The code compiles, and all the tests pass:

    # to run from the plugin's directory
    $ vim -Nu NORC --cmd "set rtp^=${PWD},${PWD}/test/vader.vim" +"cd ${PWD}/test | Vader*"
